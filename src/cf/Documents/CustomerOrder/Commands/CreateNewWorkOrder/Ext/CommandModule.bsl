
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillingValues = New Structure;
	FillingValues.Insert("OperationKind", PredefinedValue("Enum.OperationKindsCustomerOrder.WorkOrder"));
	OpenParameters = New Structure;
	OpenParameters.Insert("FillingValues", FillingValues);
	OpenForm("Document.CustomerOrder.ObjectForm", OpenParameters);
	
EndProcedure
