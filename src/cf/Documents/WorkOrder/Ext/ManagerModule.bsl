#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefWorkOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	&Company AS Company,
	|	WorkOrderWorks.Day AS Period,
	|	CASE
	|		WHEN WorkOrderWorks.Customer REFS Catalog.Counterparties
	|			THEN WorkOrderWorks.Customer
	|		WHEN WorkOrderWorks.Customer REFS Catalog.CounterpartyContracts
	|			THEN WorkOrderWorks.Customer.Owner
	|		WHEN WorkOrderWorks.Customer REFS Document.CustomerOrder
	|			THEN WorkOrderWorks.Customer.Counterparty
	|	END AS Counterparty,
	|	CASE
	|		WHEN WorkOrderWorks.Customer REFS Catalog.Counterparties
	|			THEN VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|		WHEN WorkOrderWorks.Customer REFS Catalog.CounterpartyContracts
	|			THEN WorkOrderWorks.Customer
	|		WHEN WorkOrderWorks.Customer REFS Document.CustomerOrder
	|			THEN WorkOrderWorks.Customer.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN WorkOrderWorks.Customer REFS Catalog.Counterparties
	|				OR WorkOrderWorks.Customer REFS Catalog.CounterpartyContracts
	|			THEN VALUE(Document.CustomerOrder.EmptyRef)
	|		WHEN WorkOrderWorks.Customer REFS Document.CustomerOrder
	|			THEN WorkOrderWorks.Customer
	|	END AS CustomerOrder,
	|	WorkOrderWorks.Ref.Employee,
	|	WorkOrderWorks.ProductsAndServices,
	|	WorkOrderWorks.Characteristic,
	|	WorkOrderWorks.WorkKind,
	|	WorkOrderWorks.DurationInHours AS ImportPlan,
	|	WorkOrderWorks.Amount AS AmountPlan,
	|	WorkOrderWorks.Ref.StructuralUnit,
	|	DATEADD(WorkOrderWorks.Day, MINUTE, HOUR(WorkOrderWorks.BeginTime) * 60 + MINUTE(WorkOrderWorks.BeginTime)) AS BeginTime,
	|	DATEADD(WorkOrderWorks.Day, MINUTE, HOUR(WorkOrderWorks.EndTime) * 60 + MINUTE(WorkOrderWorks.EndTime)) AS EndTime,
	|	WorkOrderWorks.Comment
	|FROM
	|	Document.WorkOrder.Works AS WorkOrderWorks
	|WHERE
	|	WorkOrderWorks.Ref = &Ref
	|	AND WorkOrderWorks.DurationInHours > 0";
	
	Query.SetParameter("Ref", DocumentRefWorkOrder);
    Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);

	Result = Query.Execute();
	TableWorkOrders = Result.Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkOrders", TableWorkOrders);
	
EndProcedure // DocumentDataInitialization()

#Region PrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName = "")
	
	SpreadsheetDocument 	= New SpreadsheetDocument;
	FirstDocument 		= True;
	
	For Each CurrentDocument IN ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		
		Query.SetParameter("Company", 		SmallBusinessServer.GetCompany(CurrentDocument.Company));
		Query.SetParameter("CurrentDocument", 	CurrentDocument);
		
		Query.Text = 
		"SELECT
		|	WorkOrder.Ref,
		|	WorkOrder.DataVersion,
		|	WorkOrder.DeletionMark,
		|	WorkOrder.Number,
		|	WorkOrder.Date,
		|	WorkOrder.Posted,
		|	WorkOrder.Company,
		|	WorkOrder.OperationKind,
		|	WorkOrder.WorkKind AS WorkKind,
		|	WorkOrder.PriceKind,
		|	WorkOrder.Employee AS Employee,
		|	WorkOrder.Employee.Code AS EmployeeCode,
		|	WorkOrder.StructuralUnit AS Department,
		|	EmployeesSliceLast.Position AS Position,
		|	WorkOrder.DocumentAmount,
		|	WorkOrder.WorkKindPosition,
		|	WorkOrder.Event,
		|	WorkOrder.Comment,
		|	WorkOrder.Author
		|FROM
		|	Document.WorkOrder AS WorkOrder
		|		LEFT JOIN InformationRegister.Employees.SliceLast(, ) AS EmployeesSliceLast
		|		ON WorkOrder.Employee = EmployeesSliceLast.Employee
		|			AND (&Company = EmployeesSliceLast.Company)
		|WHERE
		|	WorkOrder.Ref = &CurrentDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrderWorks.Ref,
		|	WorkOrderWorks.LineNumber,
		|	WorkOrderWorks.WorkKind,
		|	WorkOrderWorks.Customer,
		|	WorkOrderWorks.ProductsAndServices,
		|	WorkOrderWorks.Characteristic,
		|	WorkOrderWorks.Day AS Day,
		|	WorkOrderWorks.BeginTime AS BeginTime,
		|	WorkOrderWorks.EndTime,
		|	WorkOrderWorks.Duration,
		|	WorkOrderWorks.DurationInHours AS DurationInHours,
		|	WorkOrderWorks.Price,
		|	WorkOrderWorks.Amount AS Amount,
		|	WorkOrderWorks.Comment AS TaskDescription
		|FROM
		|	Document.WorkOrder.Works AS WorkOrderWorks
		|WHERE
		|	WorkOrderWorks.Ref = &CurrentDocument
		|
		|ORDER BY
		|	BeginTime
		|TOTALS
		|	SUM(DurationInHours),
		|	SUM(Amount)
		|BY
		|	Day";
		
		QueryResult	= Query.ExecuteBatch();
		Header 				= QueryResult[0].Select();
		Header.Next();
		
		DaysSelection			= QueryResult[1].Select(QueryResultIteration.ByGroups);
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_WorkOrder_UnifiedForm";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.WorkOrder.PF_MXL_Task");
		
		AreaHeader		= Template.GetArea("Header");
		TableHeaderArea	= Template.GetArea("TableHeader");
		AreaDay			= Template.GetArea("Day");
		AreaDetails		= Template.GetArea("Details");
		AreaTotalAmount		= Template.GetArea("Total");
		FooterArea		= Template.GetArea("Footer");
		
		AreaHeader.Parameters.Fill(Header);
		
		AreaHeader.Parameters.NumberDate = "#" + Header.Number + " dated " + Format(Header.Date, "DLF=DD");
		
		InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date, ,);
		AreaHeader.Parameters.CompanyPresentation = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,ActualAddress,PhoneNumbers,AccountNo,Bank,BIN,CorrAccount");
		
		SpreadsheetDocument.Put(AreaHeader);
		
		TableHeaderArea.Parameters.TaskKindText = NStr("en = 'Work order is '") + ?(Header.OperationKind = Enums.OperationKindsWorkOrder.External, NStr("en = 'external'"), NStr("en = 'internal'"));
		SpreadsheetDocument.Put(TableHeaderArea);
		
		TotalDurationInHours = 0;
		
		While DaysSelection.Next() Do
			
			AreaDay.Parameters.Fill(DaysSelection);
			SpreadsheetDocument.Put(AreaDay);
			
			SelectionDayWorks	= DaysSelection.Select();
			While SelectionDayWorks.Next() Do
				
				TotalDurationInHours = TotalDurationInHours + SelectionDayWorks.DurationInHours;
				AreaDetails.Parameters.Fill(SelectionDayWorks);
				
				// If kind of work is shown in TS, then generate the description 
				If Header.WorkKindPosition = Enums.AttributePositionOnForm.InTabularSection Then
					
					AreaDetails.Parameters.TaskDescription = "[" + SelectionDayWorks.WorkKind + "] " + SelectionDayWorks.TaskDescription;
					
				EndIf;
				
				
				SpreadsheetDocument.Put(AreaDetails);
				
			EndDo;
			
		EndDo;
	
		AreaTotalAmount.Parameters.Fill(Header);
		AreaTotalAmount.Parameters.DurationInHours = TotalDurationInHours;
		SpreadsheetDocument.Put(AreaTotalAmount);
		
		FooterArea.Parameters.DetailsOfResponsible = "" + Header.Employee + ?(ValueIsFilled(Header.Position), ", " + Header.Position, "");
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
		SpreadsheetDocument.Put(FooterArea);
		
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction // PrintForm()

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated by commas
//   ObjectsArray     - Array     - Array of refs to objects that need to be printed
//   PrintParameters  - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated table documents 
//   OutputParameters     - Structure    - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "WorkOrders") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "WorkOrders", "Work order", PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	SmallBusinessServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure  //Print()

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "WorkOrders";
	PrintCommand.Presentation = NStr("en='Work order';ru='Заказ наряд'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf