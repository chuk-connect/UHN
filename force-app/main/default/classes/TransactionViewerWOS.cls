/**
 * Without-sharing service class for Transaction Viewer operations.
 * Provides @AuraEnabled endpoints for the Transaction Viewer LWC.
 */
@SuppressWarnings(
  'PMD.ApexCRUDViolation,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssCount,PMD.ExcessiveClassLength'
)
public without sharing class TransactionViewerWOS {
  static User contextUser = [
    SELECT ID, ContactId
    FROM User
    WHERE id = :UserInfo.getUserId()
  ];

  private static final Integer CASE_DESCRIPTION_MAX_LENGTH = Case.Description.getDescribe()
    .getLength();

  // Allowlisted SOQL comparison operators (stored lowercase for case-insensitive matching)
  private static final Set<String> ALLOWED_OPERATORS = new Set<String>{
    '=',
    '!=',
    '<',
    '<=',
    '>',
    '>=',
    'like'
  };

  // Allowlisted SOQL date literals (the LWC emits these as hardcoded constants, never user input)
  private static final Set<String> ALLOWED_DATE_LITERALS = new Set<String>{
    'LAST_MONTH',
    'THIS_MONTH',
    'N_QUARTERS_AGO:0',
    'N_YEARS_AGO:0',
    'TODAY',
    'YESTERDAY',
    'THIS_WEEK',
    'LAST_WEEK',
    'THIS_QUARTER',
    'LAST_QUARTER',
    'THIS_YEAR',
    'LAST_YEAR'
  };

  // Allowlisted cross-object relationship paths used by the transaction filter UI.
  // Direct fields on UHN_Journal_Entry__c are validated dynamically via schema describe.
  private static final Set<String> ALLOWED_RELATIONSHIP_PATHS = new Set<String>{
    'uhn_gl_account__r.name',
    'uhn_gl_account__r.uhn_cost_element_description__c',
    'uhn_gl_account__r.uhn_pi_expense_or_revenue_type__c'
  };

  // Lazy-loaded set of field API names (lowercase) on UHN_Journal_Entry__c.
  // Populated once and reused to validate client-supplied field names.
  private static Set<String> jeSchemaFields {
    get {
      if (jeSchemaFields == null) {
        jeSchemaFields = new Set<String>(
          Schema.SObjectType.UHN_Journal_Entry__c.fields.getMap().keySet()
        );
      }
      return jeSchemaFields;
    }
    set;
  }

  /** Thrown when a transaction has an outdated transferable amount. */
  public class OutdatedTransactionException extends Exception {
  }

  /**
   * A single structured filter condition sent from the LWC.
   * All fields are validated server-side before use in a dynamic SOQL query.
   *
   * @field      SObject field API name or allowlisted relationship path
   *             (e.g., 'Name', 'UHN_GL_Account__r.Name').
   * @operator   SOQL comparison operator (=, !=, <, <=, >, >=, LIKE).
   * @value      Comparison value as a string.
   * @valueType  How value is rendered in SOQL: 'string', 'number', 'date', or 'dateLiteral'.
   */
  public class FilterCriterion {
    public String field;
    public String operator;
    public String value;
    public String valueType;
  }

  /**
   * Returns the set of Journal Entry IDs that have been tagged as already transferred
   * via paper. Runs without sharing so the exclusion set is complete regardless of
   * whether the current user has access to the parent Case on each Transfer Journal Entry.
   *
   * @return Set<Id> of journal entry IDs already transferred via paper
   */
  public static Set<Id> getPaperTransferredJEIds() {
    Set<Id> excludedIds = new Set<Id>();
    for (UHN_Transfer_Journal_Entry__c tje : [
      SELECT UHN_Journal_Entry__c
      FROM UHN_Transfer_Journal_Entry__c
      WHERE
        UHN_Rejection_or_Reduction_Reason__c = 'Rejected: Expense unavailable - Already transferred'
    ]) {
      excludedIds.add(tje.UHN_Journal_Entry__c);
    }
    return excludedIds;
  }

  /**
   * Retrieves Journal Entry records for display in the transaction viewer.
   * @param journalEntryIDs set of JE IDs to retrieve
   * @return list of Journal Entry records with display fields
   */
  public static List<UHN_Journal_Entry__c> getTransactions(
    Set<ID> journalEntryIDs
  ) {
    List<UHN_Journal_Entry__c> journalEntriesWOS = [
      SELECT
        name,
        UHN_Calculated_Date_Key__c,
        UHN_Actual_Amount__c,
        UHN_FCC__r.name,
        UHN_FCC__r.UHN_Name__c,
        UHN_GL_Account__r.UHN_Cost_Element_Description__c,
        UHN_GL_Account__r.name,
        UHN_GL_Account__r.UHN_PI_Expense_or_Revenue_Type__c,
        UHN_GL_Account__r.UHN_GL_Account_Description__c,
        UHN_Transfer_Status__c,
        UHN_Display_Amount__c,
        UHN_Absolute_Transferable_Amount__c,
        UHN_Vendor_Name__c,
        UHN_Purchase_Order_Number__c,
        UHN_Debit_or_Credit__c,
        id
      FROM UHN_Journal_Entry__c
      WHERE ID IN :journalEntryIDs
      ORDER BY UHN_Calculated_Date_Key__c ASC
    ];

    return journalEntriesWOS;
  }

  /**
   * Retrieves Journal Entry records for the reconciliation display view (fewer fields than getTransactions).
   * @param journalEntryIDs set of JE IDs to retrieve
   * @return list of Journal Entry records for reconciliation display
   */
  public static List<UHN_Journal_Entry__c> getTransactionsRD(
    Set<ID> journalEntryIDs
  ) {
    List<UHN_Journal_Entry__c> journalEntriesWOS = [
      SELECT
        name,
        UHN_Calculated_Date_Key__c,
        UHN_Actual_Amount__c,
        UHN_FCC__r.name,
        UHN_FCC__r.UHN_Name__c,
        UHN_GL_Account__r.UHN_Cost_Element_Description__c,
        UHN_GL_Account__r.name,
        UHN_GL_Account__r.UHN_PI_Expense_or_Revenue_Type__c,
        UHN_GL_Account__r.UHN_GL_Account_Description__c,
        UHN_Transfer_Status__c,
        UHN_Display_Amount__c,
        UHN_Absolute_Transferable_Amount__c,
        UHN_Vendor_Name__c,
        UHN_Purchase_Order_Number__c,
        id
      FROM UHN_Journal_Entry__c
      WHERE ID IN :journalEntryIDs
      ORDER BY UHN_Calculated_Date_Key__c ASC
    ];
    return journalEntriesWOS;
  }

  /**
   * Retrieves a filtered subset of Journal Entry IDs from within the caller-supplied
   * search pool.  Filters are expressed as a JSON-serialised List<List<FilterCriterion>>
   * (outer = AND groups, inner = OR'd criteria within each group).  Every field,
   * operator, and value is validated before use — no raw SOQL fragments are accepted.
   *
   * @param filterCriteria  JSON of List<List<FilterCriterion>>.  Pass '[[]]' for no filter.
   * @param searchPool      JSON-serialised Set<Id> of candidate Journal Entry IDs.
   * @return list of matching SObject records
   */
  // whereClause is assembled entirely from allowlist-validated components — see
  // buildFilterWhereClause → buildFilterClause → validateFilterField.
  // PMD cannot trace the multi-hop validation chain; the flag is a false positive.
  @SuppressWarnings('PMD.ApexSOQLInjection')
  @AuraEnabled(cacheable=true)
  public static List<sObject> getFilteredTransactions(
    String filterCriteria,
    String searchPool
  ) {
    try {
      Set<Id> transactionIDs = (Set<Id>) JSON.deserialize(
        searchPool,
        Set<Id>.class
      );
      List<List<FilterCriterion>> criteriaGroups = (List<List<FilterCriterion>>) JSON.deserialize(
        filterCriteria,
        List<List<FilterCriterion>>.class
      );
      String whereClause = buildFilterWhereClause(criteriaGroups);
      String query =
        'SELECT Id FROM UHN_Journal_Entry__c WHERE Id IN :transactionIDs' +
        whereClause +
        ' ORDER BY UHN_Calculated_Date_Key__c ASC';
      return Database.query(query);
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      AuraHandledException ahe = new AuraHandledException(e.getMessage());
      ahe.setMessage(e.getMessage());
      throw ahe;
    }
  }

  /**
   * Converts a structured criteria list into a SOQL WHERE clause fragment.
   * Outer list = AND groups; inner list = OR'd conditions within each group.
   * Returns an empty string when criteriaGroups is null or empty.
   *
   * @param criteriaGroups outer AND groups each containing OR'd criteria
   * @return SOQL WHERE clause fragment, or empty string
   */
  @TestVisible
  private static String buildFilterWhereClause(
    List<List<FilterCriterion>> criteriaGroups
  ) {
    if (criteriaGroups == null || criteriaGroups.isEmpty()) {
      return '';
    }
    List<String> andParts = new List<String>();
    for (List<FilterCriterion> criteriaGroup : criteriaGroups) {
      if (criteriaGroup == null || criteriaGroup.isEmpty()) {
        continue;
      }
      List<String> orParts = new List<String>();
      for (FilterCriterion criterion : criteriaGroup) {
        orParts.add(buildFilterClause(criterion));
      }
      if (orParts.size() == 1) {
        andParts.add(orParts[0]);
      } else {
        andParts.add('(' + String.join(orParts, ' OR ') + ')');
      }
    }
    if (andParts.isEmpty()) {
      return '';
    }
    return ' AND ' + String.join(andParts, ' AND ');
  }

  /**
   * Builds a single validated SOQL condition string from one FilterCriterion.
   * Throws IllegalArgumentException for any invalid field, operator, or value.
   *
   * valueType handling:
   *   'string'      → single-quoted with escapeSingleQuotes()
   *   'number'      → bare decimal literal (Decimal.valueOf validates format)
   *   'date'        → bare YYYY-MM-DD literal (regex validates format)
   *   'dateLiteral' → SOQL date keyword validated against ALLOWED_DATE_LITERALS
   *
   * @param criterion the filter condition to build
   * @return single SOQL condition string
   */
  @TestVisible
  private static String buildFilterClause(FilterCriterion criterion) {
    if (
      criterion == null ||
      String.isBlank(criterion.field) ||
      String.isBlank(criterion.operator) ||
      String.isBlank(criterion.valueType)
    ) {
      throw new IllegalArgumentException(
        'FilterCriterion is missing required fields.'
      );
    }
    validateFilterField(criterion.field);
    String op = criterion.operator.toLowerCase();
    if (!ALLOWED_OPERATORS.contains(op)) {
      throw new IllegalArgumentException(
        'Unsupported filter operator: ' + criterion.operator
      );
    }
    String rawValue = criterion.value == null ? '' : criterion.value;
    String valueType = criterion.valueType.toLowerCase();
    String valueStr;
    if (valueType == 'string') {
      valueStr = '\'' + String.escapeSingleQuotes(rawValue) + '\'';
    } else if (valueType == 'number') {
      try {
        Decimal.valueOf(rawValue);
      } catch (TypeException e) {
        throw new IllegalArgumentException(
          'Invalid numeric filter value: ' + rawValue
        );
      }
      valueStr = rawValue;
    } else if (valueType == 'date') {
      if (!Pattern.matches('\\d{4}-\\d{2}-\\d{2}', rawValue)) {
        throw new IllegalArgumentException(
          'Invalid date filter value: ' + rawValue
        );
      }
      valueStr = rawValue;
    } else if (valueType == 'dateliteral') {
      // LWC sends 'dateLiteral'; lowercased to 'dateliteral' for comparison.
      String upperValue = rawValue.toUpperCase();
      if (!ALLOWED_DATE_LITERALS.contains(upperValue)) {
        throw new IllegalArgumentException(
          'Unsupported date literal: ' + rawValue
        );
      }
      valueStr = upperValue;
    } else {
      throw new IllegalArgumentException(
        'Unsupported valueType: ' + criterion.valueType
      );
    }
    return criterion.field + ' ' + op + ' ' + valueStr;
  }

  /**
   * Validates that field is either a direct field on UHN_Journal_Entry__c
   * (checked dynamically via schema describe) or an allowlisted cross-object
   * relationship path.  Comparison is case-insensitive.
   *
   * @param field field API name or allowlisted path to validate
   * @throws IllegalArgumentException if the field is not on the allowlist.
   */
  @TestVisible
  private static void validateFilterField(String field) {
    String fieldLower = field.toLowerCase();
    if (
      jeSchemaFields.contains(fieldLower) ||
      ALLOWED_RELATIONSHIP_PATHS.contains(fieldLower)
    ) {
      return;
    }
    throw new IllegalArgumentException('Unsupported filter field: ' + field);
  }

  /**
   * Returns typeahead search results based on transaction name.
   *
   * @param textInput the search string entered by the user
   * @param searchPool JSON-serialised Set<Id> of candidate Journal Entry IDs
   * @return list of typeahead match maps
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> searchTransactions(
    String textInput,
    String searchPool
  ) {
    try {
      Set<Id> transactionIDs = (Set<Id>) JSON.deserialize(
        searchPool,
        Set<Id>.class
      );
      String regEx = '%' + textInput + '%';
      List<Map<String, Object>> mapList = new List<Map<String, Object>>();
      List<UHN_Journal_Entry__c> journalEntries = [
        SELECT name, UHN_Actual_Amount__c, id
        FROM UHN_Journal_Entry__c
        WHERE name LIKE :regEx AND ID IN :transactionIDs
        ORDER BY name ASC
        LIMIT 5
      ];

      for (UHN_Journal_Entry__c je : journalEntries) {
        String textEntity = je.name;
        String textEntityHTML = TransactionViewer.highlightMatchedText(
          textEntity,
          textInput
        );
        String textMeta = 'Amount $' + je.UHN_Actual_Amount__c * -1;
        // isGodMode: FCC Number ' + je.UHN_FCC__r.Name + '• Amount $' + je.UHN_Actual_Amount__c;
        mapList.add(
          new Map<String, Object>{
            'textEntity' => textEntity,
            'textEntityHTML' => textEntityHTML,
            'textMeta' => textMeta,
            'textMetaHTML' => null,
            'id' => je.id
          }
        );
      }
      return mapList;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Returns typeahead search results for a GL Account based on the GL description.
   *
   * @param textInput the search string entered by the user
   * @param searchPool JSON-serialised Set<Id> of candidate GL Account IDs
   * @return list of GL account match maps
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> searchGLByAccount(
    String textInput,
    String searchPool
  ) {
    try {
      Set<Id> glIDs = (Set<Id>) JSON.deserialize(searchPool, Set<Id>.class);
      String regEx = '%' + textInput + '%';
      List<Map<String, Object>> mapList = new List<Map<String, Object>>();
      List<UHN_GL_Account__c> glAcc = [
        SELECT name, UHN_Cost_Element_Description__c, id
        FROM UHN_GL_Account__c
        WHERE UHN_Cost_Element_Description__c LIKE :regEx AND ID IN :glIDs
        ORDER BY UHN_Cost_Element_Description__c ASC
        LIMIT 5
      ];
      for (UHN_GL_Account__c gl : glAcc) {
        String textEntity = gl.UHN_Cost_Element_Description__c;
        String textMeta = gl.name;
        String textEntityHTML = TransactionViewer.highlightMatchedText(
          textEntity,
          textInput
        );
        mapList.add(
          new Map<String, Object>{
            'textEntity' => textEntity,
            'textEntityHTML' => textEntityHTML,
            'textMeta' => textMeta,
            'textMetaHTML' => null,
            'id' => gl.id
          }
        );
      }
      return mapList;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Returns typeahead search results for a GL Account based on the GL name (a number).
   *
   * @param textInput the search string entered by the user
   * @param searchPool JSON-serialised Set<Id> of candidate GL Account IDs
   * @return list of GL account match maps
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> searchGLByID(
    String textInput,
    String searchPool
  ) {
    try {
      Set<Id> glIDs = (Set<Id>) JSON.deserialize(searchPool, Set<Id>.class);
      String regEx = '%' + textInput + '%';
      List<Map<String, Object>> mapList = new List<Map<String, Object>>();
      List<UHN_GL_Account__c> glAcc = [
        SELECT name, UHN_Cost_Element_Description__c, id
        FROM UHN_GL_Account__c
        WHERE name LIKE :regEx AND ID IN :glIDs
        ORDER BY name ASC
        LIMIT 5
      ];

      for (UHN_GL_Account__c gl : glAcc) {
        String textEntity = gl.UHN_Cost_Element_Description__c;
        String textMeta = gl.name;
        String textMetaHTML = TransactionViewer.highlightMatchedText(
          textMeta,
          textInput
        );
        mapList.add(
          new Map<String, Object>{
            'textEntity' => textEntity,
            'textEntityHTML' => null,
            'textMeta' => textMeta,
            'textMetaHTML' => textMetaHTML,
            'id' => gl.id
          }
        );
      }
      return mapList;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Searches for target FCCs by FCC number (name field).
   *
   * @param textInput the search string entered by the user
   * @param fccExcludeList - list of FCC IDs to exclude from results; always contains at least the source FCC
   * @return list of FCC match maps
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> searchTargetFCCsByNumber(
    String textInput,
    String fccExcludeList
  ) {
    try {
      List<Map<String, Object>> mapList = new List<Map<String, Object>>();
      String regEx = textInput + '%';
      List<UHN_FCC__c> fccRes;

      Set<Id> fccIDs = (Set<Id>) JSON.deserialize(
        fccExcludeList,
        Set<Id>.class
      );
      fccRes = [
        SELECT name, UHN_Name__c, id
        FROM UHN_FCC__c
        WHERE
          name LIKE :regEx
          AND UHN_FCC_Status__c = 'Open'
          AND ((UHN_FCC_Type_long__c = 'Grant Internal Order'
          AND UHN_NonSalary_Actuals_Allowed__c = 'Yes')
          OR UHN_FCC_Type_long__c = 'Cost Centre')
          AND ID NOT IN :fccIDs
        ORDER BY name ASC
        LIMIT 3
      ];

      for (UHN_FCC__c fcc : fccRes) {
        String textEntity = fcc.name;
        String textEntityHTML = TransactionViewer.highlightMatchedText(
          textEntity,
          textInput
        );
        String textMeta = fcc.UHN_Name__c;
        String fccURL;
        String networkId = Network.getNetworkId();
        if (networkId != null) {
          // Check if the context user is on a community page
          fccURL = Site.getBaseSecureUrl() + '/uhn-fcc/' + fcc.id;
        } else {
          fccURL = URL.getOrgDomainUrl().toExternalForm() + '/' + fcc.id;
        }
        mapList.add(
          new Map<String, Object>{
            'textEntity' => textEntity,
            'textEntityHTML' => textEntityHTML,
            'textMeta' => textMeta,
            'textMetaHTML' => null,
            'id' => fcc.id,
            'url' => fccURL
          }
        );
      }
      return mapList;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Searches for target FCCs by FCC description (UHN_Name__c field).
   *
   * @param textInput the search string entered by the user
   * @param fccExcludeList - list of FCC IDs to exclude from results; always contains at least the source FCC
   * @return list of FCC match maps
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> searchTargetFCCsByDescription(
    String textInput,
    String fccExcludeList
  ) {
    try {
      List<Map<String, Object>> mapList = new List<Map<String, Object>>();
      String regEx = '%' + textInput + '%';
      List<UHN_FCC__c> fccRes;

      Set<Id> fccIDs = (Set<Id>) JSON.deserialize(
        fccExcludeList,
        Set<Id>.class
      );
      fccRes = [
        SELECT name, UHN_Name__c, id
        FROM UHN_FCC__c
        WHERE
          UHN_Name__c LIKE :regEx
          AND UHN_FCC_Status__c = 'Open'
          AND ((UHN_FCC_Type_long__c = 'Grant Internal Order'
          AND UHN_NonSalary_Actuals_Allowed__c = 'Yes')
          OR UHN_FCC_Type_long__c = 'Cost Centre')
          AND ID NOT IN :fccIDs
        ORDER BY name ASC
        LIMIT 3
      ];

      for (UHN_FCC__c fcc : fccRes) {
        String textEntity = fcc.name;
        String textMeta = fcc.UHN_Name__c;
        String fccURL;
        String networkId = Network.getNetworkId();
        if (networkId != null) {
          // Check if the context user is on a community page
          fccURL = Site.getBaseSecureUrl() + '/uhn-fcc/' + fcc.id;
        } else {
          fccURL = URL.getOrgDomainUrl().toExternalForm() + '/' + fcc.id;
        }
        String textMetaHTML = TransactionViewer.highlightMatchedText(
          textMeta,
          textInput
        );
        mapList.add(
          new Map<String, Object>{
            'textEntity' => textEntity,
            'textEntityHTML' => null,
            'textMeta' => textMeta,
            'textMetaHTML' => textMetaHTML,
            'id' => fcc.id,
            'url' => fccURL
          }
        );
      }
      return mapList;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Create a valid approver node for the given contact.
   * Returns an empty node if the current user is the auto approver and an auto approver has already been determined.
   *
   * @param contactObj a contact who can approve an ET
   * @param isAutoApproverDetermined determines if an auto approver has already been found
   * @param validApprovers list of valid approvers to append to
   * @return approver node map
   */
  @SuppressWarnings('PMD.AvoidBooleanMethodParameters')
  public static Map<String, Object> createValidApproverNode(
    Contact contactObj,
    Boolean isAutoApproverDetermined,
    List<Map<String, Object>> validApprovers
  ) {
    String value;
    Boolean isAutoApproval;
    if (
      isAutoApproverDetermined &&
      UserInfo.getUserId() == (String) contactObj.UHN_User__c
    ) {
      return new Map<String, Object>{};
    }
    if (
      !isAutoApproverDetermined &&
      UserInfo.getUserId() == (String) contactObj.UHN_User__c
    ) {
      value = 'Auto Approve';
      isAutoApproval = true;
    } else {
      value = contactObj.UHN_Full_Name__c;
      isAutoApproval = false;
    }
    String networkId = Network.getNetworkId();
    String contactObjBaseURL;
    if (networkId != null) {
      // Check if the context user is on a community page
      contactObjBaseURL = Site.getBaseSecureUrl() + '/contact';
    } else {
      contactObjBaseURL = URL.getOrgDomainUrl().toExternalForm();
    }
    String contactObjURL = contactObjBaseURL + '/' + contactObj.id;
    Map<String, Object> approverNode = new Map<String, Object>{
      'value' => value,
      'url' => contactObjURL,
      'isAutoApproval' => isAutoApproval,
      'id' => contactObj.id,
      'userID' => contactObj.UHN_User__c,
      'contactID' => contactObj.id,
      'contactEmail' => contactObj.Email
    };
    validApprovers.add(approverNode);
    return approverNode;
  }

  /**
   * Returns the valid approvers and auto-approver for the given target FCC.
   * A valid approver must have their UHN_User__c field populated.
   * Returns a map containing:
   *    1. validApprovers — list of all valid approver nodes
   *    2. autoApprover — the node for the auto approver (for pre-filling the UI)
   *
   * @param toFccId the Salesforce ID of the target FCC
   * @param transferAmount the transfer amount used to check delegate signing limits
   * @return map with validApprovers and autoApprover keys
   */
  @SuppressWarnings('PMD.MethodNamingConventions,PMD.AvoidDeeplyNestedIfStmts')
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getTargetFCC_Approvers(
    String toFccId,
    Decimal transferAmount
  ) {
    try {
      ID fccId = ID.valueOf(toFccId);
      // Map<String, List<Map<String, Object>>>
      Map<String, Object> autoApprover = new Map<String, Object>();
      List<Map<String, Object>> validApprovers = new List<Map<String, Object>>();
      Boolean isAutoApproverDetermined = false;

      List<UHN_FCC__c> fccList = [
        SELECT UHN_Contact__c, UHN_Financial_Analyst_1__c
        FROM UHN_FCC__c
        WHERE id = :fccId
        LIMIT 1
      ];
      UHN_FCC__c fcc = fccList.get(0);

      List<Contact> accountHolderList = [
        SELECT UHN_Full_Name__c, UHN_User__c, Email, id
        FROM Contact
        WHERE
          id = :fcc.UHN_Contact__c
          AND UHN_User__c != NULL
          AND UHN_Active_User__c = TRUE
        LIMIT 1
      ];
      List<Contact> faList = [
        SELECT UHN_Full_Name__c, UHN_User__c, Email, id
        FROM Contact
        WHERE
          id = :fcc.UHN_Financial_Analyst_1__c
          AND UHN_User__c != NULL
          AND UHN_Active_User__c = TRUE
        LIMIT 1
      ];
      List<UHN_Delegate__c> delegateList = [
        SELECT
          UHN_Contact__r.UHN_Full_Name__c,
          UHN_Contact__r.UHN_User__c,
          UHN_Contact__r.Email
        FROM UHN_Delegate__c
        WHERE
          UHN_FCC__c = :fccId
          AND (UHN_Signing_Limit__c >= :transferAmount
          OR UHN_Has_Unlimited_Signing__c = TRUE)
          AND UHN_Active_User__c = TRUE
          AND UHN_Active_Record__c = TRUE
          AND UHN_Contact__r.UHN_User__c != NULL
          AND UHN_Contact__r.UHN_Active_User__c = TRUE
          AND UHN_Signing_Authority_Status__c = 'Active'
      ];
      List<Id> delegateIds = new List<Id>();
      for (UHN_Delegate__c dl : delegateList) {
        delegateIds.add(dl.UHN_Contact__c);
      }
      List<Contact> delegateContactList = [
        SELECT UHN_Full_Name__c, UHN_User__c, Email, id
        FROM Contact
        WHERE id IN :delegateIds
      ];

      // FA can only be a valid approver if he is the context user
      if (
        !faList.isEmpty() &&
        UserInfo.getUserId() == (String) faList.get(0).UHN_User__c
      ) {
        Contact fa = faList.get(0);
        Map<String, Object> approverNode = createValidApproverNode(
          fa,
          isAutoApproverDetermined,
          validApprovers
        );
        if ((Boolean) approverNode.get('isAutoApproval') == true) {
          if (approverNode.size() != 0) {
            autoApprover = approverNode;
          }
          isAutoApproverDetermined = true;
        }
      }

      if (!accountHolderList.isEmpty()) {
        Contact accountHolder = accountHolderList.get(0);
        Map<String, Object> approverNode = createValidApproverNode(
          accountHolder,
          isAutoApproverDetermined,
          validApprovers
        );
        if ((Boolean) approverNode.get('isAutoApproval') == true) {
          if (approverNode.size() != 0) {
            autoApprover = approverNode;
          }
          isAutoApproverDetermined = true;
        }
      }

      for (Contact delegate : delegateContactList) {
        Map<String, Object> approverNode = createValidApproverNode(
          delegate,
          isAutoApproverDetermined,
          validApprovers
        );
        if ((Boolean) approverNode.get('isAutoApproval') == true) {
          if (approverNode.size() != 0) {
            autoApprover = approverNode;
          }
          isAutoApproverDetermined = true;
        }
      }
      return new Map<String, Object>{
        'validApprovers' => validApprovers,
        'autoApprover' => autoApprover
      };
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Returns picklist options for ET request rationale.
   *
   * @return list of label/value maps
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> caseRationalsET() {
    try {
      List<Map<String, Object>> rationalsMapList = new List<Map<String, Object>>();
      List<Schema.PicklistEntry> pe = Schema.sObjectType.Case.fields.UHN_ET_Request_Rationale__c.getPicklistValues();
      for (Integer i = 0; i < pe.size(); i++) {
        rationalsMapList.add(
          new Map<String, Object>{ 'id' => i, 'value' => pe.get(i).getValue() }
        );
      }
      return rationalsMapList;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Creates non-salary Expense Transfer cases from the provided ET node JSON.
   * Do not modify the original transaction — this is used for cloning purposes only.
   * Changes to the transferable amount field are calculated by a rollup summary.
   *
   * @param etNodesJSON JSON-serialised List<ET_Node> describing the expense transfers to create
   * @return list of URL_Node for created cases
   */
  @SuppressWarnings('PMD.AvoidDeeplyNestedIfStmts')
  @AuraEnabled(cacheable=false)
  public static List<URL_Node> createNonSalaryET(String etNodesJSON) {
    try {
      ID caseRecordType = SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('Transfer_Request')
        .getRecordTypeId();

      List<ET_Node> etNodes = (List<ET_Node>) JSON.deserialize(
        etNodesJSON,
        List<ET_Node>.class
      );

      List<ApproverValidationRequest> validationRequests = new List<ApproverValidationRequest>();
      for (ET_Node etNode : etNodes) {
        ApproverValidationRequest req = new ApproverValidationRequest();
        req.nodeName = etNode.name;
        req.approverUserId = etNode.daUserID;
        req.toFccId = etNode.toFCC_ID;
        req.transferAmount = etNode.totalTransfer;
        validationRequests.add(req);
      }
      validateApproverSigningAuthority(validationRequests);

      List<Case> casesToInsert = new List<Case>();
      Map<String, Case> etCaseIdToCreatedCase = new Map<String, Case>();
      List<UHN_Transfer_Journal_Entry__c> transferJEsToInsert = new List<UHN_Transfer_Journal_Entry__c>();

      // Create Case records from the Expense transfer to-from pair
      for (ET_Node etNode : etNodes) {
        Case newCase = new Case(
          subject = etNode.name,
          UHN_Total_Requested_Amount__c = Decimal.valueOf(etNode.totalTransfer)
            .setScale(2, System.RoundingMode.HALF_UP),
          UHN_Total_Transfer_Amount__c = Decimal.valueOf(etNode.totalTransfer)
            .setScale(2, System.RoundingMode.HALF_UP),
          UHN_From_FCC__c = etNode.fromFCC_ID,
          UHN_To_FCC__c = etNode.toFCC_ID,
          UHN_Approver_2__c = etNode.daUserID,
          UHN_ET_Request_Rationale__c = etNode.rational,
          Description = String.isNotBlank(etNode.description)
            ? etNode.description.left(CASE_DESCRIPTION_MAX_LENGTH)
            : null,
          RecordTypeId = caseRecordType,
          ContactId = contextUser.ContactId,
          Origin = 'Lightning_Component',
          OwnerId = contextUser.id
        );
        newCase.status = etNode.daUserID == contextUser.id
          ? 'In Progress'
          : 'Awaiting Approvals';
        casesToInsert.add(newCase);
        // Collect a map of case IDs to transactions so that the transfer transaction obj can be created easily
        etCaseIdToCreatedCase.put(etNode.id, newCase);
      }
      insert casesToInsert;

      List<URL_Node> caseUrlNodes = new List<URL_Node>();

      String networkId = Network.getNetworkId();
      String caseBaseUrl;
      if (networkId != null) {
        // Check if the context user is on a community page
        caseBaseUrl = Site.getBaseSecureUrl() + '/case';
      } else {
        caseBaseUrl = URL.getOrgDomainUrl().toExternalForm();
      }

      for (Case item : casesToInsert) {
        caseUrlNodes.add(
          new URL_Node(caseBaseUrl + '/' + item.id, item.Subject)
        );
      }
      // Transactions splits can result in duplicate journal entry Ids
      Set<Id> journalEntryIdSet = new Set<Id>();
      for (ET_Node etNode : etNodes) {
        for (ET_Node.TransactionNode expenseNode : etNode.transactions) {
          String uniqueId =
            DateTime.now().format('yyyy-MM-dd-HH-mm-ss-SSS') +
            UUID.randomUUID().toString();
          UHN_Transfer_Journal_Entry__c transferJeCredit = new UHN_Transfer_Journal_Entry__c(
            UHN_Inverse__c = false, // Credit Transaction
            UHN_Requested_Amount__c = expenseNode.transferAmount * -1,
            UHN_Amount__c = expenseNode.transferAmount * -1,
            UHN_Journal_Entry__c = expenseNode.transactionID,
            UHN_Transfer_Request__c = etCaseIdToCreatedCase.get(etNode.Id).id,
            UHN_Transfer_Transaction_Pair_ID__c = uniqueId
          );
          UHN_Transfer_Journal_Entry__c transferJeDebit = new UHN_Transfer_Journal_Entry__c(
            UHN_Inverse__c = true, // Debit Transasction
            UHN_Requested_Amount__c = expenseNode.transferAmount,
            UHN_Amount__c = expenseNode.transferAmount,
            UHN_Journal_Entry__c = expenseNode.transactionID,
            UHN_Transfer_Request__c = etCaseIdToCreatedCase.get(etNode.Id).id,
            UHN_Transfer_Transaction_Pair_ID__c = uniqueId
          );
          transferJEsToInsert.add(transferJeCredit);
          transferJEsToInsert.add(transferJeDebit);
          journalEntryIdSet.add(expenseNode.transactionID);
        }
      }
      insert transferJEsToInsert;
      // update
      // Case in which a user modifies an outdated transaction and the transfer amount results in value greater than the transferrable amount. This happens when the value is a positive number
      List<UHN_Journal_Entry__c> journalEntries = [
        SELECT name
        FROM UHN_Journal_Entry__c
        WHERE ID IN :journalEntryIdSet AND UHN_Actual_Amount__c > 0
      ];
      if (!journalEntries.isEmpty()) {
        String invalidTransactions = '';
        for (UHN_Journal_Entry__c je : journalEntries) {
          invalidTransactions +=
            '<strong>' +
            je.name +
            ' ( ' +
            je.id +
            ' )' +
            '</strong>, ';
        }
        invalidTransactions = invalidTransactions.substring(
          0,
          invalidTransactions.length() - 2
        );
        throw new OutdatedTransactionException(
          'The following transactions have outdated transferrable amounts: ' +
            invalidTransactions +
            '. Please refresh the component to have updated information.'
        );
      }

      // Partition nodes: auto-approvals are stamped directly (no approval process,
      // no email); non-auto-approvals are submitted to the approval process in a
      // single bulk call so that all cases in one multi-FCC submission share one
      // DML operation regardless of how many FCC pairings the user created.
      List<Case> autoApprovalUpdates = new List<Case>();
      List<Approval.ProcessSubmitRequest> submitRequests = new List<Approval.ProcessSubmitRequest>();
      // Tracks caseId → approverUserId for manual-approval nodes so that a
      // CaseShare record can be inserted before Approval.process() is called.
      // Experience Cloud (community) approvers require explicit sharing to view
      // and act on the Case — the approval process does not auto-share the record.
      Map<Id, Id> manualApprovalCaseToApprover = new Map<Id, Id>();

      for (ET_Node etNode : etNodes) {
        Case newCase = etCaseIdToCreatedCase.get(etNode.id);
        if (etNode.daUserID == contextUser.id) {
          // Submitter IS the approver — re-derived server-side by comparing
          // the designated approver user ID to the context user. The client-
          // supplied isAutoApproval flag is intentionally ignored here to
          // prevent a crafted payload from bypassing the approval process.
          // Bypassing Approval.process() prevents an unwanted approval-request
          // email being sent back to the person who just submitted their own case.
          // Status is already 'In Progress'.
          autoApprovalUpdates.add(
            new Case(Id = newCase.Id, UHN_Approved_by_approver_2__c = true)
          );
        } else {
          Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
          req.setObjectId(newCase.id);
          req.setSubmitterId(contextUser.id);
          req.setProcessDefinitionNameOrId(
            'UHN_Transfer_Transaction_Approval_GS'
          );
          submitRequests.add(req);
          manualApprovalCaseToApprover.put(newCase.Id, etNode.daUserID);
        }
      }

      if (!autoApprovalUpdates.isEmpty()) {
        update autoApprovalUpdates;
        // Insert a CaseComment on each auto-approved case to provide an audit
        // trail. Approval.process() is bypassed for auto-approvals (no ProcessInstance
        // is created), so this comment is the only record of the approval event.
        List<CaseComment> autoApprovalComments = new List<CaseComment>();
        for (Case c : autoApprovalUpdates) {
          autoApprovalComments.add(
            new CaseComment(
              ParentId = c.Id,
              CommentBody = 'Auto-approved: submitter holds signing authority on to FCC (debited). No explicit approval required.',
              IsPublished = true
            )
          );
        }
        insert autoApprovalComments;
      }

      if (!submitRequests.isEmpty()) {
        // Grant the designated approver Edit access on each Case before
        // submitting to the approval process. Experience Cloud (community)
        // users require explicit sharing to view and act on the Case — the
        // approval process does not auto-share the record. Without this,
        // the approver receives the email but hits an access wall on click
        // and cannot approve via UI or email reply, leaving the process stuck.
        List<CaseShare> approverShares = new List<CaseShare>();
        for (Id caseId : manualApprovalCaseToApprover.keySet()) {
          approverShares.add(
            new CaseShare(
              CaseId = caseId,
              UserOrGroupId = manualApprovalCaseToApprover.get(caseId),
              CaseAccessLevel = 'Edit',
              RowCause = Schema.CaseShare.RowCause.Manual
            )
          );
        }
        // Use partial-success insert to tolerate FIELD_INTEGRITY_EXCEPTION,
        // which fires when the org-wide default already grants the approver
        // the requested access level (e.g. DEV sandbox with Public Read/Write).
        // In PROD (Private OWD) this insert is required and will succeed normally.
        for (Database.SaveResult sr : Database.insert(approverShares, false)) {
          if (!sr.isSuccess()) {
            for (Database.Error err : sr.getErrors()) {
              if (err.getStatusCode() != StatusCode.FIELD_INTEGRITY_EXCEPTION) {
                throw new System.DmlException(
                  'CaseShare insert failed: ' + err.getMessage()
                );
              }
            }
          }
        }
        List<Approval.ProcessResult> results = Approval.process(submitRequests);
        for (Approval.ProcessResult result : results) {
          if (!result.isSuccess()) {
            throw new System.DmlException(
              'Approval submission failed: ' +
              result.getErrors()[0].getMessage()
            );
          }
        }
      }
      return caseUrlNodes;
    } catch (Exception e) {
      String errorMsg = e.getTypeName() + ': ' + e.getMessage();
      AuraHandledException ahe = new AuraHandledException(errorMsg);
      ahe.setMessage(errorMsg);
      throw ahe;
    }
  }

  /** DTO for a case URL returned to the LWC. */
  public class URL_Node {
    @AuraEnabled
    public String url;
    @AuraEnabled
    public String content;

    /**
     * Constructs a URL_Node with the given URL and display content.
     * @param url full URL of the case
     * @param content subject of the case
     */
    public URL_Node(String url, String content) {
      this.url = url;
      this.content = content;
    }
  }

  /**
   * Holds the data needed to validate a single approver's signing authority
   * against a target FCC for a given transfer amount.
   */
  public class ApproverValidationRequest {
    public String nodeName;
    public String approverUserId;
    public String toFccId;
    public Decimal transferAmount;
  }

  /**
   * Validates that each requested approver has sufficient signing authority on the
   * target FCC. Approvers are valid if they are the FCC account holder, the
   * Financial Analyst (when FA is the current user), or an active delegate whose
   * signing limit meets or exceeds the transfer amount.
   *
   * @param requests List of ApproverValidationRequest objects to validate.
   * @throws AuraHandledException if any approver lacks sufficient signing authority.
   */
  @SuppressWarnings('PMD.AvoidDeeplyNestedIfStmts')
  public static void validateApproverSigningAuthority(
    List<ApproverValidationRequest> requests
  ) {
    if (requests == null || requests.isEmpty()) {
      return;
    }

    Set<Id> fccIds = new Set<Id>();
    for (ApproverValidationRequest req : requests) {
      if (!String.isBlank(req.toFccId)) {
        fccIds.add(req.toFccId);
      }
    }

    Map<Id, UHN_FCC__c> fccMap = new Map<Id, UHN_FCC__c>(
      [
        SELECT
          Id,
          UHN_Contact__r.UHN_User__c,
          UHN_Financial_Analyst_1__r.UHN_User__c
        FROM UHN_FCC__c
        WHERE Id IN :fccIds
      ]
    );

    List<UHN_Delegate__c> delegates = [
      SELECT
        UHN_FCC__c,
        UHN_Contact__r.UHN_User__c,
        UHN_Signing_Limit__c,
        UHN_Has_Unlimited_Signing__c
      FROM UHN_Delegate__c
      WHERE
        UHN_FCC__c IN :fccIds
        AND UHN_Active_User__c = TRUE
        AND UHN_Active_Record__c = TRUE
        AND UHN_Contact__r.UHN_User__c != NULL
        AND UHN_Contact__r.UHN_Active_User__c = TRUE
        AND UHN_Signing_Authority_Status__c = 'Active'
    ];

    Map<Id, List<UHN_Delegate__c>> delegatesByFcc = new Map<Id, List<UHN_Delegate__c>>();
    for (UHN_Delegate__c del : delegates) {
      if (!delegatesByFcc.containsKey(del.UHN_FCC__c)) {
        delegatesByFcc.put(del.UHN_FCC__c, new List<UHN_Delegate__c>());
      }
      delegatesByFcc.get(del.UHN_FCC__c).add(del);
    }

    Id currentUserId = UserInfo.getUserId();
    List<String> invalidNodes = new List<String>();

    for (ApproverValidationRequest req : requests) {
      // Skip requests with blank fields — treat as invalid
      if (String.isBlank(req.toFccId) || String.isBlank(req.approverUserId)) {
        invalidNodes.add(req.nodeName);
        continue;
      }

      UHN_FCC__c fcc = fccMap.get(req.toFccId);
      if (fcc == null) {
        invalidNodes.add(req.nodeName);
        continue;
      }

      // Read relationship user IDs into local variables to safely handle null lookups
      Id accountHolderUserId = fcc.UHN_Contact__r != null
        ? fcc.UHN_Contact__r.UHN_User__c
        : null;
      Id financialAnalystUserId = fcc.UHN_Financial_Analyst_1__r != null
        ? fcc.UHN_Financial_Analyst_1__r.UHN_User__c
        : null;

      // Account holder — always valid
      if (req.approverUserId == accountHolderUserId) {
        continue;
      }

      // FA — only valid if FA is the context user
      if (
        req.approverUserId == financialAnalystUserId &&
        financialAnalystUserId == currentUserId
      ) {
        continue;
      }

      // Delegate — must have sufficient signing limit (guard against null Decimal comparison)
      Boolean delegateValid = false;
      List<UHN_Delegate__c> fccDelegates = delegatesByFcc.get(req.toFccId);
      if (fccDelegates != null) {
        for (UHN_Delegate__c del : fccDelegates) {
          if (del.UHN_Contact__r.UHN_User__c == req.approverUserId) {
            if (
              del.UHN_Has_Unlimited_Signing__c == true ||
              (req.transferAmount != null &&
              del.UHN_Signing_Limit__c != null &&
              del.UHN_Signing_Limit__c >= req.transferAmount)
            ) {
              delegateValid = true;
              break;
            }
          }
        }
      }

      if (!delegateValid) {
        invalidNodes.add(req.nodeName);
      }
    }

    if (!invalidNodes.isEmpty()) {
      String msg =
        'The selected approver does not have sufficient signing authority for: ' +
        String.join(invalidNodes, ', ') +
        '. Please select a different approver with the required signing limit.';
      AuraHandledException ex = new AuraHandledException(msg);
      ex.setMessage(msg);
      throw ex;
    }
  }
}
