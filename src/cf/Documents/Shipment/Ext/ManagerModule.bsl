
#Region PrintInterface

// Document printing procedure.
//
Function PrintShipment(ObjectsArray, PrintObjects, TemplateName)
	
	Var Errors;
	
	
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_Shipment";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.Text = 
	"SELECT
	|	Shipment.Ref AS Ref,
	|	Shipment.Address AS Address,
	|	Shipment.Number AS DocumentNumber,
	|	Shipment.Date AS DocumentDate,
	|	Shipment.Company AS Company,
	|	Shipment.Counterparty AS Counterparty,
	|	Shipment.ShippingCarrier AS ShippingCarrier,	
	|	Shipment.DestMap AS DestMap,	
	
	|	Shipment.Company.Prefix AS Prefix
	|FROM
	|	Document.Shipment AS Shipment
	|WHERE
	|	Shipment.Ref IN(&ObjectsArray)
	|";
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_Shipment_Shipment";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.Shipment.PF_MXL_ShipmentTemplate");
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		InfoAboutCounterparty = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		
		If Template.Areas.Find("TitleWithLogo") <> Undefined
			AND Template.Areas.Find("TitleWithoutLogo") <> Undefined Then
			
			If ValueIsFilled(Header.Company.LogoFile) Then
				
				TemplateArea = Template.GetArea("TitleWithLogo");
				TemplateArea.Parameters.Fill(Header);
				
				PictureData = AttachedFiles.GetFileBinaryData(Header.Company.LogoFile);
				If ValueIsFilled(PictureData) Then
					
					TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
					
				EndIf;
				
			Else // If images are not selected, print regular header
				
				TemplateArea = Template.GetArea("TitleWithoutLogo");
				TemplateArea.Parameters.Fill(Header);
				
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		Else
			
			MessageText = NStr("en='ATTENTION! Maybe, custom template is being used. Default procedures of account printing may work incorrectly.';ru='ВНИМАНИЕ! Возможно используется пользовательский макет. Штатный механизм печати счетов может работать некоректно.'");
			CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		EndIf;
		
		TemplateArea = Template.GetArea("InvoiceHeaderVendor");
		
		TemplateArea.Parameters.Fill(Header);
		
		VendorPresentation	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		
		TemplateArea.Parameters.VendorPresentation	= VendorPresentation;
		TemplateArea.Parameters.VendorAddress		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "LegalAddress");
		TemplateArea.Parameters.VendorPhoneFax		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "PhoneNumbers,Fax");
		TemplateArea.Parameters.VendorEmail			= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "Email");
		
		// Customer
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("InvoiceHeaderCustomer");
		
		TemplateArea.Parameters.CustomerPresentation	= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");
		TemplateArea.Parameters.DeliveryAddress			= Header.Address;
		TemplateArea.Parameters.CustomerPhoneFax		= SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, "PhoneNumbers,Fax");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		// Carrier
		TemplateArea = Template.GetArea("InvoiceHeaderCarrier");
		
		CarrierAttributes = CommonUse.ObjectAttributesValues(Header.ShippingCarrier,"Description");
		TemplateArea.Parameters.CarrierPresentation	= CarrierAttributes.Description;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		// print map
		ImageMap = New Picture(Header.DestMap.Get());
		
		TemplateArea = Template.GetArea("ShipmentMap");
		TemplateArea.Drawings.PlaceForMap.Picture = ImageMap; 

		SpreadsheetDocument.Put(TemplateArea); 		
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;	

EndFunction // PrintForm()

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	If TemplateName = "ShipmentTemplate" Then
		
		Return PrintShipment(ObjectsArray, PrintObjects, TemplateName);
		
	EndIf;
	
EndFunction // PrintForm()

// Generate printed forms of objects
//
// Incoming:
//  TemplateNames   - String	- Names of layouts separated by commas 
//	ObjectsArray	- Array		- Array of refs to objects that need to be printed 
//	PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection	- Values table	- Generated table documents 
//	OutputParameters		- Structure     - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ShipmentTemplate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ShipmentTemplate", "Shipment", PrintForm(ObjectsArray, PrintObjects, "ShipmentTemplate"));
				
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Customer order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	// Customer order
	//
	
	// Customer order
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ShipmentTemplate";
	PrintCommand.Presentation				= NStr("en='Shipment';ru='Доставка'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsShipment";
	PrintCommand.Order						= 1;
	
		
EndProcedure

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefSalesInvoice, StructureAdditionalProperties) Export
	
	GenerateTableDeliveryTimeCounter(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
EndProcedure // DocumentDataInitialization()

// Generates values table creating data for posting by the DeliveryTimeCounter register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableDeliveryTimeCounter(DocumentRefSalesInvoice, StructureAdditionalProperties)
		
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableShipment.Date AS Period,
	|	TableShipment.ShippingCarrier AS ShippingCarrier,
	|	TableShipment.Ref AS DocShipment,
	|	TableShipment.DeliveryTimePlan AS DeliveryTimePlan,
	|	0 AS DeliveryTimeFact
	|FROM
	|	Document.Shipment AS TableShipment
	|WHERE
	|	TableShipment.Ref = &Ref
	|	AND TableShipment.DeliveryTimePlan > 0";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("DeliveryTimeCounterTable", QueryResult.Unload());
	
EndProcedure
