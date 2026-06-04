trigger UHN_CaseTrigger on Case(before insert, before update) {
  UHN_CaseTriggerHelper.dispatch(Trigger.operationType, Trigger.new);
}
