
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("OperationKindWorkOrder", True);
	OpenForm("Document.CustomerOrder.Form.PaymentDocumentsListForm", OpenParameters, , "WorkOrderPaymentDocumentsListForm");
	
EndProcedure
