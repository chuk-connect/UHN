@IsTest
private class AAR_EvaluatorGroupServiceTest {
  @TestSetup
  static void setup() {
    List<Group> existing = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = 'AAR_Evaluators' AND Type = 'Regular'
      LIMIT 1
    ];
    if (existing.isEmpty()) {
      insert new Group(
        Name = 'AAR_Evaluators',
        DeveloperName = 'AAR_Evaluators',
        Type = 'Regular'
      );
    }
  }

  @IsTest
  static void addUsersToGroup_addsUserToGroup() {
    Group grp = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = 'AAR_Evaluators'
      LIMIT 1
    ];

    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User u = new User(
      FirstName = 'Test',
      LastName = 'Evaluator',
      Email = 'test.evaluator@example.com',
      Username = 'test.evaluator.' +
        System.currentTimeMillis() +
        '@example.test',
      Alias = 'tevl',
      TimeZoneSidKey = 'America/Toronto',
      LocaleSidKey = 'en_CA',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = p.Id
    );
    insert u;

    Test.startTest();
    AAR_EvaluatorGroupService.addUsersToGroup(grp.Id, new Set<Id>{ u.Id });
    Test.stopTest();

    List<GroupMember> members = [
      SELECT Id
      FROM GroupMember
      WHERE GroupId = :grp.Id AND UserOrGroupId = :u.Id
    ];
    System.assertEquals(
      1,
      members.size(),
      'User should be a member of AAR_Evaluators group'
    );
  }

  @IsTest
  static void addUsersToGroup_idempotent_noDuplicateMembers() {
    Group grp = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = 'AAR_Evaluators'
      LIMIT 1
    ];

    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User u = new User(
      FirstName = 'Test2',
      LastName = 'Evaluator',
      Email = 'test2.evaluator@example.com',
      Username = 'test2.evaluator.' +
        System.currentTimeMillis() +
        '@example.test',
      Alias = 'te2vl',
      TimeZoneSidKey = 'America/Toronto',
      LocaleSidKey = 'en_CA',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = p.Id
    );
    insert u;

    insert new GroupMember(GroupId = grp.Id, UserOrGroupId = u.Id);

    Test.startTest();
    AAR_EvaluatorGroupService.addUsersToGroup(grp.Id, new Set<Id>{ u.Id });
    Test.stopTest();

    List<GroupMember> members = [
      SELECT Id
      FROM GroupMember
      WHERE GroupId = :grp.Id AND UserOrGroupId = :u.Id
    ];
    System.assertEquals(
      1,
      members.size(),
      'Should not insert duplicate group membership'
    );
  }

  @IsTest
  static void addToEvaluatorsGroup_noLinkedUser_noError() {
    Contact c = new Contact(LastName = 'NoUser');
    insert c;

    Test.startTest();
    AAR_EvaluatorGroupService.addToEvaluatorsGroup(new List<Id>{ c.Id });
    Test.stopTest();

    System.assert(
      true,
      'Should complete without exception when no linked user exists'
    );
  }

  @IsTest
  static void addToEvaluatorsGroup_emptyList_noError() {
    Test.startTest();
    AAR_EvaluatorGroupService.addToEvaluatorsGroup(new List<Id>());
    Test.stopTest();
    System.assert(true, 'Should complete without exception for empty input');
  }

  @IsTest
  static void addToEvaluatorsGroup_nullInput_noError() {
    Test.startTest();
    AAR_EvaluatorGroupService.addToEvaluatorsGroup(null);
    Test.stopTest();
    System.assert(true, 'Should complete without exception for null input');
  }
}
