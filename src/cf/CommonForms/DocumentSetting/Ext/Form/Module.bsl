////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Procedure write user settings in register.
//
Procedure SetSetting(SettingName)	
	
	User = Users.CurrentUser();
	
	RecordSet = InformationRegisters.UserSettings.CreateRecordSet();
	
	RecordSet.Filter.User.Use = True;
	RecordSet.Filter.User.Value	  = User;
	RecordSet.Filter.Setting.Use	  = True;
	RecordSet.Filter.Setting.Value		  = ChartsOfCharacteristicTypes.UserSettings[SettingName];
	
	Record = RecordSet.Add();
	
	Record.User = User;
	Record.Setting    = ChartsOfCharacteristicTypes.UserSettings[SettingName];
	Record.Value     = ChartsOfCharacteristicTypes.UserSettings[SettingName].ValueType.AdjustValue(ThisForm[SettingName]);
	
	RecordSet.Write();
	
EndProcedure // WriteNewSettings()

&AtServer
// Procedure write user settings in register.
//
Procedure WriteNewSettings()
	
	If ValueIsFilled(WorkKindPositionInWorkOrder) Then
		SetSetting("WorkKindPositionInWorkOrder");
	EndIf;
	If ValueIsFilled(WorkKindPositionInWorkTask) Then
		SetSetting("WorkKindPositionInWorkTask");
	EndIf;
	If ValueIsFilled(ShipmentDatePositionInCustomerOrder) Then
		SetSetting("ShipmentDatePositionInCustomerOrder");
	EndIf;
	If ValueIsFilled(ReceiptDatePositionInPurchaseOrder) Then
		SetSetting("ReceiptDatePositionInPurchaseOrder");
	EndIf;
	If ValueIsFilled(CustomerOrderPositionInShipmentDocuments) Then
		SetSetting("CustomerOrderPositionInShipmentDocuments");
	EndIf;
	If ValueIsFilled(CustomerOrderPositionInInventoryTransfer) Then
		SetSetting("CustomerOrderPositionInInventoryTransfer");
	EndIf;
	If ValueIsFilled(PurchaseOrderPositionInReceiptDocuments) Then
		SetSetting("PurchaseOrderPositionInReceiptDocuments");
	EndIf;	 
	If ValueIsFilled(UseConsumerMaterialsInWorkOrder) Then
		SetSetting("UseConsumerMaterialsInWorkOrder");
	EndIf;	 
	If ValueIsFilled(UseProductsInWorkOrder) Then
		SetSetting("UseProductsInWorkOrder");
	EndIf;	 
	If ValueIsFilled(UseMaterialsInWorkOrder) Then
		SetSetting("UseMaterialsInWorkOrder");
	EndIf;
	If ValueIsFilled(UsePerformerSalariesInWorkOrder) Then
		SetSetting("UsePerformerSalariesInWorkOrder");
	EndIf;
	If ValueIsFilled(PositionAssignee) Then
		SetSetting("PositionAssignee");
	EndIf;
	If ValueIsFilled(PositionResponsible) Then
		SetSetting("PositionResponsible");
	EndIf;
	
	RefreshReusableValues();
	
EndProcedure // WriteNewSettings()

&AtClient
// Procedure checks if the form was modified.
//
Procedure CheckIfFormWasModified(StructureOfFormAttributes)

	WereMadeChanges = False;
	
	ChangesOfPositionOfWorkKindInWorkOrder						= WorkKindPositionInWorkOrderOnOpen <> WorkKindPositionInWorkOrder;
	ChangesOfWorkKindPositionInWorkTask					= WorkKindPositionInWorkTaskOnOpen <> WorkKindPositionInWorkTask;
	ChangesOfShipmentDatePositionInCustomerOrder				= ShipmentDatePositionInCustomerOrderOnOpen <> ShipmentDatePositionInCustomerOrder;
	ChangesOfReceiptDatePositionInPurchaseOrder			= ReceiptDatePositionInPurchaseOrderOnOpen <> ReceiptDatePositionInPurchaseOrder;
	ChangesOfCustomerOrderPositionInShipmentDocuments		= CustomerOrderPositionInShipmentDocumentsOnOpen <> CustomerOrderPositionInShipmentDocuments;
	ChangesOfCustomerOrderPositionInInventoryTransfer		= CustomerOrderPositionInInventoryTransferOnOpen <> CustomerOrderPositionInInventoryTransfer;
	ChangesOfPurchaseOrderPositionInReceiptDocuments	= LocationOfSupplierOrderInIncomeDocumentsOnOpen <> PurchaseOrderPositionInReceiptDocuments;
	ChangesOfUseConsumerMaterialsInWorkOrder			= UseConsumerMaterialsInWorkOrderOnOpen <> UseConsumerMaterialsInWorkOrder;
	ChangesOfUseGoodsInWorkOrder						= UseGoodsInWorkOrderOnOpen <> UseProductsInWorkOrder;
	ChangesOfUseMaterialsInWorkOrder					= UseMaterialsInWorkOrderOnOpen <> UseMaterialsInWorkOrder;
	ChangesOfUsePerformerSalariesInWorkOrder		= UsePerformerSalariesInWorkOrderOnOpen <> UsePerformerSalariesInWorkOrder;
	ChangesOfPositionAssignee								= PositionAssigneeOnOpen <> PositionAssignee;
	ChangesOfPositionResponsible								= PositionResponsibleOnOpen <> PositionResponsible;
	
	If ChangesOfPositionOfWorkKindInWorkOrder
	 OR ChangesOfWorkKindPositionInWorkTask
	 OR ChangesOfShipmentDatePositionInCustomerOrder
	 OR ChangesOfReceiptDatePositionInPurchaseOrder
	 OR ChangesOfCustomerOrderPositionInShipmentDocuments
	 OR ChangesOfCustomerOrderPositionInInventoryTransfer
	 OR ChangesOfPurchaseOrderPositionInReceiptDocuments 
	 OR ChangesOfUseConsumerMaterialsInWorkOrder
	 OR ChangesOfUseGoodsInWorkOrder
	 OR ChangesOfUseMaterialsInWorkOrder
	 OR ChangesOfUsePerformerSalariesInWorkOrder
	 OR ChangesOfPositionAssignee
	 OR ChangesOfPositionResponsible Then
		
		WereMadeChanges = True;
		
	EndIf;
	
	StructureOfFormAttributes.Insert("WereMadeChanges",							 		WereMadeChanges);
	StructureOfFormAttributes.Insert("WorkKindPositionInWorkOrder",					 		WorkKindPositionInWorkOrder);
	StructureOfFormAttributes.Insert("WorkKindPositionInWorkTask",				 		WorkKindPositionInWorkTask);
	StructureOfFormAttributes.Insert("ShipmentDatePositionInCustomerOrder",			 		ShipmentDatePositionInCustomerOrder);
	StructureOfFormAttributes.Insert("ReceiptDatePositionInPurchaseOrder",		 		ReceiptDatePositionInPurchaseOrder);
	StructureOfFormAttributes.Insert("CustomerOrderPositionInShipmentDocuments",	 		CustomerOrderPositionInShipmentDocuments);
	StructureOfFormAttributes.Insert("CustomerOrderPositionInInventoryTransfer",	 		CustomerOrderPositionInInventoryTransfer);
	StructureOfFormAttributes.Insert("PurchaseOrderPositionInReceiptDocuments", 		PurchaseOrderPositionInReceiptDocuments);
	StructureOfFormAttributes.Insert("UseConsumerMaterialsInWorkOrder",		 		UseConsumerMaterialsInWorkOrder);
	StructureOfFormAttributes.Insert("UseProductsInWorkOrder",					 		UseProductsInWorkOrder);
	StructureOfFormAttributes.Insert("UseMaterialsInWorkOrder",				 		UseMaterialsInWorkOrder);
	StructureOfFormAttributes.Insert("UsePerformerSalariesInWorkOrder",	 		UsePerformerSalariesInWorkOrder);
	StructureOfFormAttributes.Insert("PositionResponsible",							 		PositionResponsible);
	StructureOfFormAttributes.Insert("PositionAssignee",							 		PositionAssignee);
	
EndProcedure // CheckIfFormWasModified()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	WereMadeChanges = False;
	RememberSelection = False;
	
	If Parameters.Property("WorkKindPositionInWorkOrder") Then
		WorkKindPositionInWorkOrder = Parameters.WorkKindPositionInWorkOrder;
		WorkKindPositionInWorkOrderOnOpen = Parameters.WorkKindPositionInWorkOrder;
		Items.GroupWorkKindPositionInWorkOrder.Visible = True;
		Items.WorkKindPositionInWorkOrder.Visible = True;
	Else
		Items.GroupWorkKindPositionInWorkOrder.Visible = False;
		Items.WorkKindPositionInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("WorkKindPositionInWorkTask") Then
		WorkKindPositionInWorkTask = Parameters.WorkKindPositionInWorkTask;
		WorkKindPositionInWorkTaskOnOpen = Parameters.WorkKindPositionInWorkTask;
		Items.GroupPositionOfWorkKindInWorkTask.Visible = True;
		Items.WorkKindPositionInWorkTask.Visible = True;
	Else
		Items.GroupPositionOfWorkKindInWorkTask.Visible = False;
		Items.WorkKindPositionInWorkTask.Visible = False;
	EndIf;
	
	If Parameters.Property("ShipmentDatePositionInCustomerOrder") Then
		ShipmentDatePositionInCustomerOrder = Parameters.ShipmentDatePositionInCustomerOrder;
		ShipmentDatePositionInCustomerOrderOnOpen = Parameters.ShipmentDatePositionInCustomerOrder;
		Items.GroupShipmentDatePositionInCustomerOrder.Visible = True;
		Items.ShipmentDatePositionInCustomerOrder.Visible = True;
	Else
		Items.GroupShipmentDatePositionInCustomerOrder.Visible = False;
		Items.ShipmentDatePositionInCustomerOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("ReceiptDatePositionInPurchaseOrder") Then
		ReceiptDatePositionInPurchaseOrder = Parameters.ReceiptDatePositionInPurchaseOrder;
		ReceiptDatePositionInPurchaseOrderOnOpen = Parameters.ReceiptDatePositionInPurchaseOrder;
		Items.GroupReceiptDatePositionInPurchaseOrder.Visible = True;
		Items.ReceiptDatePositionInPurchaseOrder.Visible = True;
	Else
		Items.GroupReceiptDatePositionInPurchaseOrder.Visible = False;
		Items.ReceiptDatePositionInPurchaseOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("CustomerOrderPositionInShipmentDocuments") Then
		CustomerOrderPositionInShipmentDocuments = Parameters.CustomerOrderPositionInShipmentDocuments;
		CustomerOrderPositionInShipmentDocumentsOnOpen = Parameters.CustomerOrderPositionInShipmentDocuments;
		Items.GroupCustomerOrderPositionInShipmentDocuments.Visible = True;
		Items.CustomerOrderPositionInShipmentDocuments.Visible = True;
	Else
		Items.GroupCustomerOrderPositionInShipmentDocuments.Visible = False;
		Items.CustomerOrderPositionInShipmentDocuments.Visible = False;
	EndIf;
	
	If Parameters.Property("CustomerOrderPositionInInventoryTransfer") Then
		CustomerOrderPositionInInventoryTransfer = Parameters.CustomerOrderPositionInInventoryTransfer;
		CustomerOrderPositionInInventoryTransferOnOpen = Parameters.CustomerOrderPositionInInventoryTransfer;
		Items.GroupCustomerOrderPositionInInventoryTransfer.Visible = True;
		Items.CustomerOrderPositionInInventoryTransfer.Visible = True;
	Else
		Items.GroupCustomerOrderPositionInInventoryTransfer.Visible = False;
		Items.CustomerOrderPositionInInventoryTransfer.Visible = False;
	EndIf;
	
	If Parameters.Property("PurchaseOrderPositionInReceiptDocuments") Then
		PurchaseOrderPositionInReceiptDocuments = Parameters.PurchaseOrderPositionInReceiptDocuments;
		LocationOfSupplierOrderInIncomeDocumentsOnOpen = Parameters.PurchaseOrderPositionInReceiptDocuments;
		Items.GroupPurchaseOrderPositionInReceiptDocuments.Visible = True;
		Items.PurchaseOrderPositionInReceiptDocuments.Visible = True;
	Else
		Items.GroupPurchaseOrderPositionInReceiptDocuments.Visible = False;
		Items.PurchaseOrderPositionInReceiptDocuments.Visible = False;
	EndIf;
	
	If Parameters.Property("UseConsumerMaterialsInWorkOrder") Then
		UseConsumerMaterialsInWorkOrder = Parameters.UseConsumerMaterialsInWorkOrder;
		UseConsumerMaterialsInWorkOrderOnOpen = Parameters.UseConsumerMaterialsInWorkOrder;
		Items.GroupUseConsumerMaterialsInWorkOrder.Visible = True;
		Items.UseConsumerMaterialsInWorkOrder.Visible = True;
	Else
		Items.GroupUseConsumerMaterialsInWorkOrder.Visible = False;
		Items.UseConsumerMaterialsInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("UseProductsInWorkOrder") Then
		UseProductsInWorkOrder = Parameters.UseProductsInWorkOrder;
		UseGoodsInWorkOrderOnOpen = Parameters.UseProductsInWorkOrder;
		Items.GroupUseProductsInWorkOrder.Visible = True;
		Items.UseProductsInWorkOrder.Visible = True;
	Else
		Items.GroupUseProductsInWorkOrder.Visible = False;
		Items.UseProductsInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("UseMaterialsInWorkOrder") Then
		UseMaterialsInWorkOrder = Parameters.UseMaterialsInWorkOrder;
		UseMaterialsInWorkOrderOnOpen = Parameters.UseMaterialsInWorkOrder;
		Items.GroupUseMaterialsInWorkOrder.Visible = True;
		Items.UseMaterialsInWorkOrder.Visible = True;
	Else
		Items.GroupUseMaterialsInWorkOrder.Visible = False;
		Items.UseMaterialsInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("UsePerformerSalariesInWorkOrder") Then
		UsePerformerSalariesInWorkOrder = Parameters.UsePerformerSalariesInWorkOrder;
		UsePerformerSalariesInWorkOrderOnOpen = Parameters.UsePerformerSalariesInWorkOrder;
		Items.GroupUsePerformerSalariesInWorkOrder.Visible = True;
		Items.UsePerformerSalariesInWorkOrder.Visible = True;
	Else
		Items.GroupUsePerformerSalariesInWorkOrder.Visible = False;
		Items.UsePerformerSalariesInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("PositionAssignee") Then
		PositionAssignee = Parameters.PositionAssignee;
		PositionAssigneeOnOpen = Parameters.PositionAssignee;
		Items.GroupPositionAssignee.Visible = True;
		Items.PositionAssignee.Visible = True;
	Else
		Items.GroupPositionAssignee.Visible = False;
		Items.PositionAssignee.Visible = False;
	EndIf;
	
	If Parameters.Property("PositionResponsible") Then
		PositionResponsible = Parameters.PositionResponsible;
		LocationLocationResponsibleOnOpen = Parameters.PositionResponsible;
		Items.GroupPositionResponsible.Visible = True;
		Items.PositionResponsible.Visible = True;
	Else
		Items.GroupPositionResponsible.Visible = False;
		Items.PositionResponsible.Visible = False;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure OK(Command)
	
	StructureOfFormAttributes = New Structure;
	
	CheckIfFormWasModified(StructureOfFormAttributes);
	
	Close(StructureOfFormAttributes);
	
EndProcedure // CommandOK()

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure RememberSelection(Command)
	
	StructureOfFormAttributes = New Structure;
	
	CheckIfFormWasModified(StructureOfFormAttributes);
	
	WriteNewSettings();
	
	Close(StructureOfFormAttributes);
	
EndProcedure // RememberSelection()
