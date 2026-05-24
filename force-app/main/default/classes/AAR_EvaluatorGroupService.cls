public with sharing class AAR_EvaluatorGroupService {
  @InvocableMethod(
    label='Add Contact User to AAR Evaluators Group'
    description='Finds the active Salesforce User linked to each Contact and adds them to the AAR_Evaluators public group. Safe to call repeatedly — skips existing members.'
  )
  public static void addToEvaluatorsGroup(List<Id> contactIds) {
    if (contactIds == null || contactIds.isEmpty())
      return;

    List<Group> groups = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = 'AAR_Evaluators' AND Type = 'Regular'
      LIMIT 1
    ];
    if (groups.isEmpty())
      return;
    Id groupId = groups[0].Id;

    List<User> linkedUsers = [
      SELECT Id
      FROM User
      WHERE ContactId IN :contactIds AND IsActive = TRUE
    ];
    if (linkedUsers.isEmpty())
      return;

    Set<Id> userIds = new Map<Id, User>(linkedUsers).keySet();

    Set<Id> alreadyMembers = new Set<Id>();
    for (GroupMember gm : [
      SELECT UserOrGroupId
      FROM GroupMember
      WHERE GroupId = :groupId AND UserOrGroupId IN :userIds
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
      insert toInsert;
    }
  }
}
