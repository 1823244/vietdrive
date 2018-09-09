
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf (FillingData) <> Type("DocumentRef.CustomerOrder") Then
		Return;
	EndIf;
	
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.CustomerOrder")]		= "FillByCustomerOrder";
	
	ObjectFillingSB.FillDocument(ThisObject, FillingData, FillingStrategy);
	
	
EndProcedure

Procedure FillByCustomerOrder(FillingData) Export
	
	// Header filling.
	AttributeValues = CommonUse.GetAttributeValues(FillingData, 
			New Structure("Company, Counterparty"));
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, Counterparty");
	ThisObject.BasisDocument = FillingData;
	
	// Tabular section "CustomerOrders" filling
	NewRow = CustomerOrders.Add();
	NewRow.CustomerOrder = FillingData;
		
EndProcedure


Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	PerformanceEstimationClientServer.StartTimeMeasurement("ShipmentDocumentPostingInitialization");
	
	Documents.Shipment.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingMovementsCreation");
	

	// DeliveryTime
	SmallBusinessServer.ReflectDeliveryTimeCounter(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingMovementsRecords");
	
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	

EndProcedure

