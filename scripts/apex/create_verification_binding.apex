Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
cmd.fullName = 'Verification_Binding.Publication_Author';
cmd.label = 'Publication Author';

Metadata.CustomMetadataValue valChild = new Metadata.CustomMetadataValue();
valChild.field = 'Child_Object__c';
valChild.value = 'UHN_Publication_Author__c';

Metadata.CustomMetadataValue valParent = new Metadata.CustomMetadataValue();
valParent.field = 'Parent_Lookup_Field__c';
valParent.value = 'UHN_Contact__c';

cmd.values = new List<Metadata.CustomMetadataValue>{ valChild, valParent };

Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
mdContainer.addMetadata(cmd);

Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
System.debug('Metadata deploy job ID: ' + jobId);
