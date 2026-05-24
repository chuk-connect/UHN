trigger UHN_CaseTrigger on Case (before insert, before update) {

	if (Trigger.isInsert)
		UHN_CaseTriggerHelper.beforeInsert(Trigger.new);
	if (Trigger.isUpdate)
		UHN_CaseTriggerHelper.beforeUpdate(Trigger.new);
}