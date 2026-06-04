/**
 * Service that adds contact-linked users to the AAR_Evaluators public group.
 * Used as an @InvocableMethod from Flow.
 */
public with sharing class AAR_EvaluatorGroupService {
  /**
   * Adds the Salesforce Users linked to the supplied Contact IDs to the AAR_Evaluators public group.
   * Safe to call repeatedly — existing members are skipped.
   * @param contactIds List of Contact Ids whose linked Users should be added to the AAR_Evaluators group.
   */
  @InvocableMethod(
    label='Add Contact User to AAR Evaluators Group'
    description='Finds the active Salesforce User linked to each Contact and adds them to the AAR_Evaluators public group. Safe to call repeatedly — skips existing members.'
  )
  public static void addToEvaluatorsGroup(List<Id> contactIds) {
    if (contactIds == null || contactIds.isEmpty()) {
      return;
    }

    List<Group> groups = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = 'AAR_Evaluators' AND Type = 'Regular'
      WITH USER_MODE
      LIMIT 1
    ];
    if (groups.isEmpty()) {
      return;
    }
    Id groupId = groups[0].Id;

    List<User> linkedUsers = [
      SELECT Id
      FROM User
      WHERE ContactId IN :contactIds AND IsActive = TRUE
      WITH USER_MODE
    ];
    if (linkedUsers.isEmpty()) {
      return;
    }

    addUsersToGroup(groupId, new Map<Id, User>(linkedUsers).keySet());
  }

  /**
   * Adds a set of users to a public group, skipping any who are already members.
   * @param groupId The Id of the Group to add members to.
   * @param userIds The set of User Ids to add.
   */
  @TestVisible
  private static void addUsersToGroup(Id groupId, Set<Id> userIds) {
    Set<Id> alreadyMembers = new Set<Id>();
    for (GroupMember gm : [
      SELECT UserOrGroupId
      FROM GroupMember
      WHERE GroupId = :groupId AND UserOrGroupId IN :userIds
      WITH USER_MODE
    ]) {
      alreadyMembers.add(gm.UserOrGroupId);
    }

    List<GroupMember> toInsert = new List<GroupMember>();
    for (Id uid : userIds) {
      if (!alreadyMembers.contains(uid)) {
        toInsert.add(new GroupMember(GroupId = groupId, UserOrGroupId = uid));
      }
    }

    if (!toInsert.isEmpty()) {
      if (!Schema.sObjectType.GroupMember.isCreateable()) {
        throw new System.SecurityException(
          'Insufficient access to create GroupMember'
        );
      }
      insert toInsert;
    }
  }
}
