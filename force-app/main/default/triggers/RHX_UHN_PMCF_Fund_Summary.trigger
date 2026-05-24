trigger RHX_UHN_PMCF_Fund_Summary on UHN_PMCF_Fund_Summary__c
    (after delete, after insert, after undelete, after update, before delete) {
           Type rollClass = System.Type.forName('rh2', 'ParentUtil');
        if(rollClass != null) {
              rh2.ParentUtil pu = (rh2.ParentUtil) rollClass.newInstance();
         if (trigger.isAfter) {
                        pu.performTriggerRollups(trigger.oldMap, trigger.newMap, new String[]{'UHN_PMCF_Fund_Summary__c'}, null);
           }
    }
}