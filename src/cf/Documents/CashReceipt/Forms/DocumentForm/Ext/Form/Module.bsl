﻿
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Object.PaymentDetails.Count() = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
	EndIf;
	
	DocumentObject = FormAttributeToValue("Object");
	If DocumentObject.IsNew()
	AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If ValueIsFilled(Parameters.BasisDocument) Then
			DocumentObject.Fill(Parameters.BasisDocument);
			ValueToFormAttribute(DocumentObject, "Object");
		EndIf;
		If Not ValueIsFilled(Object.PettyCash) Then
			Object.PettyCash = Catalogs.PettyCashes.GetPettyCashByDefault(Object.Company);
			Object.CashCurrency = ?(ValueIsFilled(Object.PettyCash.CurrencyByDefault), Object.PettyCash.CurrencyByDefault, Object.CashCurrency);
		EndIf;
		If ValueIsFilled(Object.Counterparty)
		   AND Object.PaymentDetails.Count() > 0
		   AND Not ValueIsFilled(Parameters.BasisDocument) Then
			If Not ValueIsFilled(Object.PaymentDetails[0].Contract) Then
				Object.PaymentDetails[0].Contract = Object.Counterparty.ContractByDefault;
			EndIf;
			If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
				ContractCurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.PaymentDetails[0].Contract.SettlementsCurrency));
				Object.PaymentDetails[0].ExchangeRate = ?(ContractCurrencyRateRepetition.ExchangeRate = 0, 1, ContractCurrencyRateRepetition.ExchangeRate);
				Object.PaymentDetails[0].Multiplicity = ?(ContractCurrencyRateRepetition.Multiplicity = 0, 1, ContractCurrencyRateRepetition.Multiplicity);
			EndIf;
		EndIf;
		SetCFItem();
	EndIf;
	
	// Form attributes setting.
	SubsidiaryCompany = SmallBusinessServer.GetCompany(Object.Company);
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.CashCurrency));
	
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Constants.AccountingCurrency.Get()));
	
	AccountingCurrencyRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	AccountingCurrencyMultiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
	SupplementOperationKindsChoiceList();
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.Basis)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	Else
		SetVisibleOfVATTaxation();
	EndIf;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		DefaultVATRate = Object.Company.DefaultVATRate;
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
		DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
	Else
		DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
	EndIf;
	
	OperationKind = Object.OperationKind;
	CashCurrency = Object.CashCurrency;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration3.Visible = PrintReceiptEnabled;
		Items.ReceiptCRNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
	AccountingCurrency = Constants.AccountingCurrency.Get();
	
	// Fill in tabular section while entering a document from the working place.
	If TypeOf(Parameters.FillingValues) = Type("Structure")
	   AND Parameters.FillingValues.Property("FillDetailsOfPayment")
	   AND Parameters.FillingValues.FillDetailsOfPayment Then
		
		TabularSectionRow = Object.PaymentDetails[0];
		
		TabularSectionRow.PaymentAmount = Object.DocumentAmount;
		TabularSectionRow.ExchangeRate = ?(
			TabularSectionRow.ExchangeRate = 0,
			1,
			TabularSectionRow.ExchangeRate
		);
		
		TabularSectionRow.Multiplicity = ?(
			TabularSectionRow.Multiplicity = 0,
			1,
			TabularSectionRow.Multiplicity
		);
		
		TabularSectionRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.PaymentAmount,
			ExchangeRate,
			TabularSectionRow.ExchangeRate,
			Multiplicity,
			TabularSectionRow.Multiplicity
		);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((TabularSectionRow.VATRate.Rate + 100) / 100);
		
	EndIf;
	
	SetVisibilityItemsDependenceOnOperationKind();
	SetVisibilitySettlementAttributes();
	
	SmallBusinessClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	 PropertiesManagement.OnCreateAtServer(ThisForm, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetChoiceParameterLinksAvailableTypes();
	SetCurrentPage();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter)
		   AND Object.Counterparty = Parameter Then
			SetVisibilitySettlementAttributes();
		EndIf;
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCashReceiptPosting");
	// StandardSubsystems.PerformanceEstimation
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(Object.PaymentDetails, MessageText, Object.Ref, Object.Company, Object.Counterparty, Object.OperationKind, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en='Document is not posted! ';ru='Документ не проведен! '") + MessageText, MessageText);
			Message.Message();
			
			If Cancel Then
				Return;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	LineCount = Object.PaymentDetails.Count();
	
	// Notification about payment.
	NotifyAboutBillPayment = False;
	NotifyAboutOrderPayment = False;
	
	For Each CurRow IN Object.PaymentDetails Do
		NotifyAboutBillPayment = ?(
			NotifyAboutBillPayment,
			NotifyAboutBillPayment,
			ValueIsFilled(CurRow.InvoiceForPayment)
		);
		NotifyAboutOrderPayment = ?(
			NotifyAboutOrderPayment,
			NotifyAboutOrderPayment,
			ValueIsFilled(CurRow.Order)
		);
	EndDo;
	
	If NotifyAboutBillPayment Then
		Notify("NotificationAboutBillPayment");
	EndIf;
	
	If NotifyAboutOrderPayment Then
		Notify("NotificationAboutOrderPayment");
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

#Region OtherSettlements

&AtClient
Procedure OtherSettlementsCorrespondenceOnChange(Item)
	
	If Correspondence <> Object.Correspondence Then
		SetVisibilityAttributesDependenceOnCorrespondence();
		Correspondence = Object.Correspondence;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region FormItemEventHandlersTablePaymentDetails

&AtClient
Procedure PaymentDetailsOtherSettlementsBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsContractOnChange(Item)
	
	ProcessOnChangeCounterpartyContractOtherSettlements();
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Object.Counterparty.IsEmpty() Then
		StandardProcessing = False;
		
		Message = New UserMessage;
		Message.Text = NStr("ru = 'Сначала выберите контрагента'; en = 'First select the counterparty'");
		Message.Field = "Object.Counterparty";
		Message.Message();
		
		Return;
	EndIf;
	
	ProcessStartChoiceCounterpartyContractOtherSettlements(Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsSettlementsAmountOnChange(Item)
	
	CalculatePaymentAmountAtClient(Items.PaymentDetailsOtherSettlements.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;

EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsExchangeRateOnChange(Item)
		
	CalculatePaymentAmountAtClient(Items.PaymentDetailsOtherSettlements.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsMultiplicityOnChange(Item)
		
	CalculatePaymentAmountAtClient(Items.PaymentDetailsOtherSettlements.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsPaymentAmountOnChange(Item)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		1,
		TablePartRow.ExchangeRate
	);
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity
	);
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.SettlementsAmount = 0,
		1,
		TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount * ExchangeRate
	);
	
	If Not ValueIsFilled(TablePartRow.VATRate) Then
		TablePartRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATAmountAtClient(TablePartRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsVATRateOnChange(Item)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateVATAmountAtClient(TablePartRow);

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CalculatePaymentAmountAtClient(TablePartRow, ColumnName = "")
	
	StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TablePartRow.Contract
		);
		
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		?(StructureData.ContractCurrencyRateRepetition.ExchangeRate =0, 1, StructureData.ContractCurrencyRateRepetition.ExchangeRate),
		TablePartRow.ExchangeRate
	);
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity
	);
	
	If TablePartRow.SettlementsAmount = 0 Then
		TablePartRow.PaymentAmount = 0;
		TablePartRow.ExchangeRate = StructureData.ContractCurrencyRateRepetition.ExchangeRate;
	ElsIf Object.CashCurrency = StructureData.SettlementsCurrency Then
		TablePartRow.PaymentAmount = TablePartRow.SettlementsAmount;
	ElsIf TablePartRow.PaymentAmount = 0 Or
		(ColumnName = "ExchangeRate" Or ColumnName = "Multiplicity") Then
		If TablePartRow.ExchangeRate = 0 Then
			TablePartRow.PaymentAmount = 0;
		Else
			TablePartRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TablePartRow.SettlementsAmount,
				TablePartRow.ExchangeRate,
				ExchangeRate,
				TablePartRow.Multiplicity,
				Multiplicity
			);
		EndIf;
	Else
		TablePartRow.ExchangeRate = ?(
			TablePartRow.SettlementsAmount = 0 Or TablePartRow.PaymentAmount = 0,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate, //TablePartRow.ExchangeRate,
			TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount * ExchangeRate
		);
		TablePartRow.Multiplicity = ?(
			TablePartRow.SettlementsAmount = 0 Or TablePartRow.PaymentAmount = 0,
			StructureData.ContractCurrencyRateRepetition.Multiplicity,
			TablePartRow.Multiplicity
		);
	EndIf;
	
	If Not ValueIsFilled(TablePartRow.VATRate) Then
		TablePartRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATAmountAtClient(TablePartRow);
	
EndProcedure // CalculatePaymentAmountAtClient()

&AtClient
Procedure CalculateVATAmountAtClient(TablePartRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TablePartRow.VATRate);
	
	TablePartRow.VATRate = TablePartRow.PaymentAmount - (TablePartRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure // CalculateVATAmountAtClient()

&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractKinds", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetDataPaymentDetailsContractOnChange(Date, Contract, PlanningDocument = Undefined)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)
		)
	);
	StructureData.Insert("SettlementsCurrency", Contract.SettlementsCurrency);
	
	Return StructureData;
	
EndFunction // GetDataPaymentDetailsContractOnChange()

&AtServer
Procedure OperationKindOnChangeAtServer()
	
	SetChoiceParameterLinksAvailableTypes();
	
	SetVisibilityPrintReceipt();
	
	If OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting")
	 OR Not ValueIsFilled(OperationKind) Then
		User = Users.CurrentUser();
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDepartment");
		Object.Department = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDepartment);
	EndIf;
	
	// Other settlement
	If Object.OperationKind = Enums.OperationKindsCashReceipt.OtherSettlements Then
		DefaultVATRate			= SmallBusinessReUse.GetVATRateWithoutVAT();
		DefaultVATRateNumber	= SmallBusinessReUse.GetVATRateValue(DefaultVATRate);
		Object.PaymentDetails[0].VATRate = DefaultVATRate;
	// End Other settlement
	Else
		FillVATRateByCompanyVATTaxation();
	EndIf;
		
	SetVisibilityItemsDependenceOnOperationKind();
	SetCFItemWhenChangingTheTypeOfOperations();
	
EndProcedure // OperationKindOnChangeAtServer()

&AtClient
Procedure ProcessOnChangeCounterpartyContractOtherSettlements()
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	
	If ValueIsFilled(TablePartRow.Contract) Then
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TablePartRow.Contract,
			TablePartRow.PlanningDocument
		);
		TablePartRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate
		);
		TablePartRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Multiplicity
		);
		
	EndIf;
	
	TablePartRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TablePartRow.PaymentAmount,
		ExchangeRate,
		TablePartRow.ExchangeRate,
		Multiplicity,
		TablePartRow.Multiplicity
	);
	
EndProcedure // ProcessOnChangeCounterpartyContractOtherSettlements()

&AtClient
Procedure ProcessStartChoiceCounterpartyContractOtherSettlements(Item, StandardProcessing)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	If TablePartRow = Undefined Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, TablePartRow.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure // ProcessStartChoiceCounterpartyContractOtherSettlements()

&AtServer
Procedure SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem()

	Item = Items.OtherSettlementsCorrespondence;
	
	ChoiceParametersItem	= New Array;
	FilterByAccountType		= New Array;

	For Each Parameter In Item.ChoiceParameters Do
		If Parameter.Name = "Filter.TypeOfAccount" Тогда
			FilterByAccountType.Add(Enums.GLAccountsTypes.Debitors);
			FilterByAccountType.Add(Enums.GLAccountsTypes.Creditors);
			
			ChoiceParametersItem.Add(New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(FilterByAccountType)));
		Else
			ChoiceParametersItem.Add(Parameter);
		EndIf;
	EndDo;
	
	Item.ChoiceParameters = New FixedArray(ChoiceParametersItem);
	
EndProcedure

&AtServer
Procedure SetChoiceParametersOnMetadataForAccountItem()

	Item = Items.OtherSettlementsCorrespondence;
	
	ChoiceParametersItem	= New Array;
	FilterByAccountType		= New Array;
	
	ChoiceParametersFromMetadata = Object.Ref.Metadata().Attributes.Correspondence.ChoiceParameters;
	For Each Parameter In ChoiceParametersFromMetadata Do
		ChoiceParametersItem.Add(Parameter);
	EndDo;
	
	Item.ChoiceParameters = New FixedArray(ChoiceParametersItem);
	
EndProcedure

&AtServer
Procedure SetVisibilityAttributesDependenceOnCorrespondence()
	
	SetVisibilityPlanningDocument();
	
EndProcedure // SetVisibilityAttributesDependenceOnCorrespondence()

&AtServer
Procedure SetVisibilityItemsDependenceOnOperationKind()
	
	Items.PaymentDetailsPaymentAmount.Visible					= GetFunctionalOption("CurrencyTransactionsAccounting");
	Items.OtherSettlementsPaymentAmount.Visible					= GetFunctionalOption("CurrencyTransactionsAccounting");
	Items.PaymentDetailsOtherSettlementsPaymentAmount.Visible	= GetFunctionalOption("CurrencyTransactionsAccounting");
	
	Items.SettlementsWithCounterparty.Visible		= False;
	Items.SettlementsWithAdvanceHolder.Visible		= False;
	Items.RetailIncome.Visible						= False;
	Items.RetailIncomeAccrualAccounting.Visible		= False;
	Items.CurrencyPurchase.Visible					= False;
	Items.AdvanceHolderPaymentsPaymentDetailsPaymentAmount.Visible	= False;
	Items.OtherSettlements.Visible					= False;
	Items.RetailIncomePaymentDetailsVATRate.Visible	= False;
	Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible	= False;
	Items.VATTaxation.Visible		= False;
	Items.PlanningDocuments.Title	= NStr("ru = 'Планирование'; en = 'Planning'");
	Items.DocumentAmount.Width	= 14;
	Items.AdvanceHolder.Visible	= False;
	Items.Counterparty.Visible	= False;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromCustomer") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= True;
		Items.PaymentDetailsFillDetails.Visible		= True;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("ru = 'Покупатель'; en = 'Customer'");
		Items.VATTaxation.Visible	= True;
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Object.Counterparty");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.PaymentDetailsInvoiceForPayment.ChoiceParameterLinks = NewConnections;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		=  NStr("ru = 'Сумма платежа'; en = 'Payment amount'");
		Items.SettlementsAmount.Visible	= Not GetFunctionalOption("CurrencyTransactionsAccounting");
		
		Items.VATAmount.Visible	= Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromVendor") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= False;
		Items.PaymentDetailsFillDetails.Visible		= False;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("ru = 'Поставщик'; en = 'Supplier'");
		Items.VATTaxation.Visible	= True;
		
		NewArray = New Array();
		NewConnection = New ChoiceParameterLink("Filter.Counterparty", "Object.Counterparty");
		NewArray.Add(NewConnection);
		NewConnections = New FixedArray(NewArray);
		Items.PaymentDetailsInvoiceForPayment.ChoiceParameterLinks = NewConnections;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("ru = 'Сумма платежа'; en = 'Payment amount'");
		Items.SettlementsAmount.Visible	= Not GetFunctionalOption("CurrencyTransactionsAccounting");
		
		Items.VATAmount.Visible	= Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromAdvanceHolder") Then
		
		Items.VATTaxation.Visible					= False;
		Items.SettlementsWithAdvanceHolder.Visible	= True;
		
		Items.AdvanceHolderPaymentsPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.AdvanceHolder.Visible	= True;
		Items.DocumentAmount.Width	= 13;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"), NStr("en='Amount (plan)';ru='Сумма (план)'"), NStr("ru='Сумма платежа'; en = 'Payment amount'"));
		Items.SettlementsAmount.Visible	= False;
		Items.VATAmount.Visible			= False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.RetailIncome") Then
		
		Items.AdvanceHolderPaymentsPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.RetailIncome.Visible	= True;
		Items.VATTaxation.Visible	= True;
		Items.RetailIncomePaymentDetailsVATRate.Visible			= Object.VATTaxation <> Enums.VATTaxationTypes.NotTaxableByVAT;
		Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible	= Object.VATTaxation <> Enums.VATTaxationTypes.NotTaxableByVAT;
		
		If GetFunctionalOption("PaymentCalendar") Then
			Items.PlanningDocuments.Title = NStr("ru = 'Планирование, НДС'; en = 'Planning, VAT'");
		Else
			Items.PlanningDocuments.Title = NStr("ru = 'НДС'; en = 'VAT'");
		EndIf;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"), NStr("en='Amount (plan)';ru='Сумма (план)'"), NStr("ru='Сумма платежа'; en = 'Payment amount'"));
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible			= Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting") Then
		
		Items.AdvanceHolderPaymentsPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.RetailIncomeAccrualAccounting.Visible	= True;
		Items.VATTaxation.Visible					= True;
		Items.RetailIncomePaymentDetailsVATRate.Visible			= Object.VATTaxation <> Enums.VATTaxationTypes.NotTaxableByVAT;
		Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible	= Object.VATTaxation <> Enums.VATTaxationTypes.NotTaxableByVAT;
		
		If GetFunctionalOption("PaymentCalendar") Then
			Items.PlanningDocuments.Title = NStr("ru = 'Планирование, НДС'; en = 'Planning, VAT'");
		Else
			Items.PlanningDocuments.Title = NStr("ru = 'НДС'; en = 'VAT'");
		EndIf;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"), NStr("en='Amount (plan)';ru='Сумма (план)'"), NStr("ru='Сумма платежа'; en = 'Payment amount'"));
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible			= Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.CurrencyPurchase") Then
		
		Items.AdvanceHolderPaymentsPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.CurrencyPurchase.Visible	= True;
		
		Items.PaymentAmount.Visible 		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en='Amount (plan)';ru='Сумма (план)'"), NStr("ru='Сумма платежа'; en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.VATAmount.Visible				= False;
		
	// Other settlements	
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.Other") Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible 		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en='Amount (plan)';ru='Сумма (план)'"), NStr("ru='Сумма платежа'; en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.VATAmount.Visible				= False;
		
		Items.AdvanceHolderPaymentsPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.PageOtherSettlementsAsList.Visible	= False;
		Items.GroupAttributesFirstRow.Visible		= False;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.OtherSettlements") Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= False;
		Items.PaymentAmount.Title			= NStr("ru='Сумма платежа'; en = 'Payment amount'");
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.VATAmount.Visible				= False;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("ru = 'Контрагент'; en = 'Counterparty'");
		Items.PageOtherSettlementsAsList.Visible	= True;
		Items.OtherSettlementsContract.Visible		= Object.Counterparty.DoOperationsByContracts;
		Items.GroupAttributesFirstRow.Visible		= True;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		If Object.PaymentDetails.Count() > 0 Then
			ID = Object.PaymentDetails[0].GetID();
			Items.PaymentDetailsOtherSettlements.CurrentRow = ID;
		EndIf;
		
	// End Other settlements	
	Else
		
		Items.AdvanceHolderPaymentsPaymentDetailsPaymentAmount.Visible = GetFunctionalOption("PaymentCalendar");
		Items.OtherSettlements.Visible = True;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en='Amount (plan)';ru='Сумма (план)'");
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure // ItemsSetVisibleDependingOnOperationKind()

&AtServer
Procedure SetVisibilityPlanningDocument()
	
	If Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer
		OR Object.OperationKind = Enums.OperationKindsCashReceipt.FromVendor
		OR (NOT GetFunctionalOption("PaymentCalendar")
		AND Items.RetailIncomePaymentDetailsVATRate.Visible = False
		AND Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible = False) Then
		Items.PlanningDocuments.Visible = False;
	// Other settlements
	ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.OtherSettlements Then
		Items.PlanningDocuments.Visible = False;
	// End Other settlements
	Else
		Items.PlanningDocuments.Visible = True;
	EndIf;
	
EndProcedure // SetVisibilityPlanningDocument()

&AtServer
Procedure SetVisibilitySettlementAttributes()
	
	CounterpartyDoOperationsByContracts = Object.Counterparty.DoOperationsByContracts;
	
	Items.PaymentDetailsContract.Visible			= CounterpartyDoOperationsByContracts;
	Items.PaymentDetailsDocument.Visible			= Object.Counterparty.DoOperationsByDocuments;
	Items.PaymentDetailsOrder.Visible				= Object.Counterparty.DoOperationsByOrders;
	Items.PaymentDetailsInvoiceForPayment.Visible	= Object.Counterparty.TrackPaymentsByBills;
	
	// Other settlements
	Items.OtherSettlementsContract.Visible = CounterpartyDoOperationsByContracts;
	// End Other settlements
	
EndProcedure // SetVisibilitySettlementAttributes()

#EndRegion

#Region ExternalFormViewManagement

&AtServer
Procedure SetVisibilityPrintReceipt()
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration3.Visible = PrintReceiptEnabled;
		Items.ReceiptCRNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetChoiceParameterLinksAvailableTypes()
	
	// Other settlemets
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.OtherSettlements") Then
		SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem();
	Else
		SetChoiceParametersOnMetadataForAccountItem();
	EndIf;
	// End Other settlemets
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromCustomer") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.FixedAssetsTransfer"));
		Array.Add(Type("DocumentRef.AcceptanceCertificate"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.CustomerInvoice"));
		Array.Add(Type("DocumentRef.CustomerOrder"));
		Array.Add(Type("DocumentRef.AgentReport"));
		Array.Add(Type("DocumentRef.ProcessingReport"));
		Array.Add(Type("DocumentRef.Netting"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetails.ChildItems.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.CustomerOrder", , );
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.InvoiceForPayment", , );
		Items.PaymentDetailsInvoiceForPayment.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("ru = 'Оплачиваемый документ отгрузки товаров, работ и услуг контрагенту'; en = 'Paid document of shipment of goods, works and services to a counterparty'");
		
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromVendor") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.ExpenseReport"));
		Array.Add(Type("DocumentRef.CashPayment"));
		Array.Add(Type("DocumentRef.PaymentExpense"));
		Array.Add(Type("DocumentRef.Netting"));
		Array.Add(Type("DocumentRef.AdditionalCosts"));
		Array.Add(Type("DocumentRef.ReportToPrincipal"));
		Array.Add(Type("DocumentRef.SubcontractorReport"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.CustomerInvoice"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder", , );
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SupplierInvoiceForPayment", , );
		Items.PaymentDetailsInvoiceForPayment.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("ru = 'Документ расчетов с контрагентом, по которому осуществляется возврат денежных средств'; en = 'Document of settlements with counterparty according to which cash assets are returned'");
		
	EndIf;
	
EndProcedure // SetAvailableTypesSelectionParameterLinks()

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItemWhenChangingTheTypeOfOperations()
	
	If (Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer
		OR Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncome
		OR Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting)
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.FromVendor 
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.Other) Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf (Object.OperationKind = Enums.OperationKindsCashReceipt.FromAdvanceHolder
		OR Object.OperationKind = Enums.OperationKindsCashReceipt.CurrencyPurchase
		OR Object.OperationKind = Enums.OperationKindsCashReceipt.Other)
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure // OperationKindOnChangeAtServer()

// The procedure sets CF item when opening the form.
//
&AtServer
Procedure SetCFItem()
	
	If Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer
		OR Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncome
		OR Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.FromVendor Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	Else
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure // OperationKindOnChangeAtServer()

// Procedure expands the operation kinds selection list.
//
&AtServer
Procedure SupplementOperationKindsChoiceList()
	
	If Constants.FunctionalOptionAccountingRetail.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashReceipt.RetailIncome);
		Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting);
	EndIf;
	
	If Constants.FunctionalCurrencyTransactionsAccounting.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashReceipt.CurrencyPurchase);
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashReceipt.Other);
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCashReceipt.OtherSettlements);
	
EndProcedure // SupplementOperationKindsChoiceList()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	SetVisibleOfVATTaxation();
	SetVisibilitySettlementAttributes();
	
EndProcedure // FillByDocument()

// Function puts the SettlementsDetails tabular section to
// the temporary storage and returns an address
//
&AtServer
Function PlacePaymentDetailsToStorage()
	
	Return PutToTempStorage(
		Object.PaymentDetails.Unload(,
			"Contract,
			|AdvanceFlag,
			|Document,
			|Order,
			|SettlementsAmount,
			|ExchangeRate,
			|Multiplicity"
		),
		UUID
	);
	
EndFunction // PlacePaymentDetailsToStorage()

// Function receives the SettlementsDetails tabular section from the temporary storage.
//
&AtServer
Procedure GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage)
	
	TableExplanationOfPayment = GetFromTempStorage(AddressPaymentDetailsInStorage);
	Object.PaymentDetails.Clear();
	For Each RowPaymentDetails IN TableExplanationOfPayment Do
		String = Object.PaymentDetails.Add();
		FillPropertyValues(String, RowPaymentDetails);
	EndDo;
	
EndProcedure // GetPaymentDetailsFromStorage()

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure RecalculateDocumentAmounts(ExchangeRate, Multiplicity, RecalculatePaymentAmount)
	
	For Each TabularSectionRow IN Object.PaymentDetails Do
		If RecalculatePaymentAmount Then
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				ExchangeRate,
				TabularSectionRow.Multiplicity,
				Multiplicity
			);
			CalculateVATSUM(TabularSectionRow);
		Else
			TabularSectionRow.ExchangeRate = ?(
				TabularSectionRow.ExchangeRate = 0,
				1,
				TabularSectionRow.ExchangeRate
			);
			TabularSectionRow.Multiplicity = ?(
				TabularSectionRow.Multiplicity = 0,
				1,
				TabularSectionRow.Multiplicity
			);
			TabularSectionRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.PaymentAmount,
				ExchangeRate,
				TabularSectionRow.ExchangeRate,
				Multiplicity,
				TabularSectionRow.Multiplicity
			);
		EndIf;
	EndDo;
	
	If RecalculatePaymentAmount Then
		Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
	EndIf;
	
EndProcedure // RecalculateDocumentAmounts()

// Recalculates amounts by the cash assets currency.
//
&AtClient
Procedure RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText)
	
	ExchangeRateBeforeChange = ExchangeRate;
	MultiplicityBeforeChange = Multiplicity;
	
	If ValueIsFilled(Object.CashCurrency) Then
		ExchangeRate = ?(
			StructureData.CurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.CurrencyRateRepetition.ExchangeRate
		);
		Multiplicity = ?(
			StructureData.CurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.CurrencyRateRepetition.Multiplicity
		);
		If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.CurrencyPurchase") Then
			Object.ExchangeRate = ExchangeRate;
			Object.Multiplicity = Multiplicity;
		EndIf;
	EndIf;
	
	// If currency exchange rate is not changed or cash
	// assets currency is not filled in or document is not filled in, then do nothing.
	If (ExchangeRate = ExchangeRateBeforeChange
		AND Multiplicity = MultiplicityBeforeChange)
	 OR (NOT ValueIsFilled(Object.CashCurrency))
	 OR (Object.PaymentDetails.Total("SettlementsAmount") = 0
	 AND Not ValueIsFilled(Object.DocumentAmount)) Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeRateBeforeChange", ExchangeRateBeforeChange);
	AdditionalParameters.Insert("MultiplicityBeforeChange", MultiplicityBeforeChange);
	
	NotifyDescription = New NotifyDescription("DetermineNeedForDocumentAmountRecalculation", ThisObject, AdditionalParameters);
	
	ShowQueryBox(NOTifyDescription, MessageText, QuestionDialogMode.YesNo);
	
EndProcedure // RecalculateAmountsOnCashAssetsCurrencyRateChange()

// Recalculate a payment amount in the passed tabular section string.
//
&AtClient
Procedure CalculatePaymentSUM(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		ExchangeRate,
		TabularSectionRow.Multiplicity,
		Multiplicity
	);
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure // CalculatePaymentAmount()

// Perform recalculation of the amount accounting.
//
&AtClient
Procedure CalculateAccountingAmount()
	
	Object.ExchangeRate = ?(
		Object.ExchangeRate = 0,
		1,
		Object.ExchangeRate
	);
	Object.Multiplicity = ?(
		Object.Multiplicity = 0,
		1,
		Object.Multiplicity
	);
	
	Object.AccountingAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		Object.DocumentAmount,
		Object.ExchangeRate,
		AccountingCurrencyRate,
		Object.Multiplicity,
		AccountingCurrencyMultiplicity
	);
	
EndProcedure // CalculatePaymentAmount()

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure // CalculateVATAmount()

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, Date)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"CounterpartyDescriptionFull",
		Counterparty.DescriptionFull
	);
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", ContractByDefault.SettlementsCurrency)
		)
	);
	
	StructureData.Insert(
		"DoOperationsByContracts",
		Counterparty.DoOperationsByContracts
	);
	
	StructureData.Insert(
		"DoOperationsByDocuments",
		Counterparty.DoOperationsByDocuments
	);
	
	StructureData.Insert(
		"DoOperationsByOrders",
		Counterparty.DoOperationsByOrders
	);
	
	StructureData.Insert(
		"TrackPaymentsByBills",
		Counterparty.TrackPaymentsByBills
	);
	
	SetVisibilitySettlementAttributes();
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataCashAssetsCurrencyOnChange(Date, CashCurrency)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(
			Date,
			New Structure("Currency", CashCurrency)
		)
	);
	
	Return StructureData;
	
EndFunction // GetDataCashAssetsCurrencyOnChange()

// Receives data set from the server for the AdvanceHolderOnChange procedure.
//
&AtServerNoContext
Function GetDataAdvanceHolderOnChange(AdvanceHolder)
	
	StructureData = New Structure;
	
	StructureData.Insert("AdvanceHolderDescription", AdvanceHolder.Description);
	
	Return StructureData;
	
EndFunction // GetDataAdvanceHolderOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.CashCurrency));
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateRepetition
	);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	StructureData.Insert("SubsidiaryCompany", SmallBusinessServer.GetCompany(Object.Company));
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Procedure fills in default VAT rate.
//
&AtServer
Procedure FillDefaultVATRate()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		DefaultVATRate = Object.Company.DefaultVATRate;
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
		DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
	Else
		DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
	EndIf;
	
EndProcedure // FillDefaultVATRate()

// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	If Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer Then
		
		Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company,, Object.Date);
		
	ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncome Then
		
		Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company, Object.CashCR.StructuralUnit, Object.Date);
		
	ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting Then
		
		Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company, Object.StructuralUnit, Object.Date);
		
	ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.FromAdvanceHolder Then
		
		Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT;
		
	Else
		
		Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT;
		
	EndIf;
	
	If Not (Object.OperationKind = Enums.OperationKindsCashReceipt.FromAdvanceHolder
		OR Object.OperationKind = Enums.OperationKindsCashReceipt.Other
		OR Object.OperationKind = Enums.OperationKindsCashReceipt.CurrencyPurchase)
	   AND Not TaxationBeforeChange = Object.VATTaxation Then
		
		FillVATRateByVATTaxation();
		
	Else
		
		FillDefaultVATRate();
		
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

// Procedure fills the VAT rate in the tabular section according to the taxation system.
//
&AtServer
Procedure FillVATRateByVATTaxation(RestoreRatesOfVAT = True)
	
	FillDefaultVATRate();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		If Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer
			OR Object.OperationKind = Enums.OperationKindsCashReceipt.FromVendor Then
			
			Items.PaymentDetailsVATRate.Visible = True;
			Items.PaymentDetailsVatAmount.Visible = True;
			Items.VATAmount.Visible = True;
			
		ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncome
			OR Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting Then
			
			Items.RetailIncomePaymentDetailsVATRate.Visible = True;
			Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible = True;
			Items.VATAmount.Visible = True;
			
		EndIf;
		
		VATRate = SmallBusinessReUse.GetVATRateValue(DefaultVATRate);
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow IN Object.PaymentDetails Do
				TabularSectionRow.VATRate = Object.Company.DefaultVATRate;
				TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
			EndDo;
		EndIf;
		
	Else
		
		If Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer
			OR Object.OperationKind = Enums.OperationKindsCashReceipt.FromVendor Then
			
			Items.PaymentDetailsVATRate.Visible = False;
			Items.PaymentDetailsVatAmount.Visible = False;
			Items.VATAmount.Visible = False;
			
		ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncome
			OR Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting Then
			
			Items.RetailIncomePaymentDetailsVATRate.Visible = False;
			Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible = False;
			Items.VATAmount.Visible = False;
			
		EndIf;
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow IN Object.PaymentDetails Do
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
			EndDo;
		EndIf;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure // FillVATRateByVATTaxation()

// Procedure sets the Taxation field visible.
//
&AtServer
Procedure SetVisibleOfVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		If Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer
		 OR Object.OperationKind = Enums.OperationKindsCashReceipt.FromVendor Then
			
			Items.PaymentDetailsVATRate.Visible = True;
			Items.PaymentDetailsVatAmount.Visible = True;
			
		ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncome
			OR Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting Then
			
			Items.RetailIncomePaymentDetailsVATRate.Visible = True;
			Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible = True;
			
		EndIf;
		
		DefaultVATRate = Object.Company.DefaultVATRate;
		
	Else
		
		If Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer
			OR Object.OperationKind = Enums.OperationKindsCashReceipt.FromVendor Then
			
			Items.PaymentDetailsVATRate.Visible = False;
			Items.PaymentDetailsVatAmount.Visible = False;
			
		ElsIf Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncome
			OR Object.OperationKind = Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting Then
			
			Items.RetailIncomePaymentDetailsVATRate.Visible = False;
			Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible = False;
			
		EndIf;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then	
			DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		Else
			DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
		EndIf;
		
	EndIf;
	
EndProcedure // SetVisibleVATTaxation()

// Procedure executes actions while changing counterparty contract.
//
&AtClient
Procedure ProcessCounterpartyContractChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TabularSectionRow.Contract
		);
		TabularSectionRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate
		);
		TabularSectionRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Multiplicity
		);
	EndIf;
	
	TabularSectionRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity
	);
	
EndProcedure // ProcessCounterpartyContractChange()

// Procedure executes actions while starting to select a counterparty contract.
//
&AtClient
Procedure ProcessStartChoiceCounterpartyContract(Item, StandardProcessing)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, TabularSectionRow.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure // ProcessCounterpartyContractChange()

// Procedure fills in the PaymentDetails TS string with the settlements document data.
//
&AtClient
Procedure ProcessAccountsDocumentSelection(DocumentData)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	If TypeOf(DocumentData) = Type("Structure") Then
		
		TabularSectionRow.Document = DocumentData.Document;
		TabularSectionRow.Order = DocumentData.Order;
		TabularSectionRow.InvoiceForPayment = DocumentData.InvoiceForPayment;
		
		If Not ValueIsFilled(TabularSectionRow.Contract) Then
			TabularSectionRow.Contract = DocumentData.Contract;
			ProcessCounterpartyContractChange();
		EndIf;
		
		RunActionsOnAccountsDocumentChange();
		
		Modified = True;
		
	EndIf;
	
EndProcedure // ProcessSettlementsDocumentSelection()

// Procedure determines an advance flag depending on the settlements document type.
//
&AtClient
Procedure RunActionsOnAccountsDocumentChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromVendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashPayment")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure // ExecuteActionsOnSettlementsDocumentChange()

// Procedure is filling the payment details.
//
&AtServer
Procedure FillPaymentDetails(CurrentObject = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.FillPaymentDetails();
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure // FillPaymentDetails()

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(PettyCash)
	
	Return PettyCash.CurrencyByDefault;
	
EndFunction // GetPettyCashDefaultCurrencyOnServer()

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(Val TSPaymentDetails, MessageText, Document, Company, Counterparty, OperationKind, Cancel)
	
	If Not SmallBusinessReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	
	For Each TabularSectionRow IN TSPaymentDetails Do
		
		If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, TabularSectionRow.Contract, Company, Counterparty, ContractKindsList)
			AND Constants.DoNotPostDocumentsWithIncorrectContracts.Get() Then
			
			Cancel = True;
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Gets the default contract depending on the settlements method.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure sets the current page depending on the operation kind.
//
&AtClient
Procedure SetCurrentPage()
	
	LineCount = Object.PaymentDetails.Count();
	
	If LineCount = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		LineCount = 1;
	EndIf;
	
EndProcedure // SetCurrentPage()

// The procedure clears the attributes that could have been
// filled in earlier but do not belong to the current operation.
//
&AtClient
Procedure ClearAttributesNotRelatedToOperation()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromCustomer")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromVendor") Then
		Object.Correspondence = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.BusinessActivity = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessActivity = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.InvoiceForPayment = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.RetailIncome") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessActivity = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.InvoiceForPayment = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.RetailIncomeAccrualAccounting") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.SettlementsAmount = 0;
			TableRow.ExchangeRate = 0;
			TableRow.Multiplicity = 0;
			TableRow.Order = Undefined;
			TableRow.InvoiceForPayment = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.Other") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessActivity = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.InvoiceForPayment = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.CurrencyPurchase") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessActivity = Undefined;
		Object.ExchangeRate = ?(ValueIsFilled(ExchangeRate),
			ExchangeRate,
			1
		);
		Object.Multiplicity = ?(ValueIsFilled(Multiplicity),
			Multiplicity, 1
		);
		CalculateAccountingAmount();
		For Each TableRow IN Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.InvoiceForPayment = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	EndIf;
	
EndProcedure // ClearAttributesNotRelatedToOperation()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// The procedure is called when you click "PrintReceipt" on the command panel.
//
&AtClient
Procedure PrintReceipt(Command)
	
	If Object.ReceiptCRNumber <> 0 Then
		MessageText = NStr("en='Receipt has already been issued on the fiscal data recorder.';ru='Чек уже пробит на фискальном регистраторе!'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	ShowMessageBox = False;
	If SmallBusinessClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If EquipmentManagerClient.RefreshClientWorkplace() Then
			
			NotifyDescription = New NotifyDescription("EnableFiscalRegistrarEnd", ThisObject);
			EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "FiscalRegister",
					NStr("en='Select a fiscal data recorder';ru='Выберите фискальный регистратор'"), NStr("en='Fiscal data recorder is not connected.';ru='Фискальный регистратор не подключен.'"));
			
		Else
			
			MessageText = NStr("en='First, you need to select the work place of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'");
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en='Failed to post document';ru='Не удалось выполнить проведение документа'"));
	EndIf;
	
EndProcedure // PrintReceipt()

&AtClient
Procedure EnableFiscalRegistrarEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
		
		// Enable FR.
		Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
		);
		
		If Result Then
			
			// Prepare data.
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			SectionNumber = 2;
			
			// Preparation of the product table
			ProductsTable = New Array();
			
			ProductsTableRow = New ValueList();
			ProductsTableRow.Add(NStr("en='Payment as of:';ru='Оплата от:'") + " " + Object.AcceptedFrom + Chars.LF
			+ NStr("en='Basis:';ru='Основание:'") + " " + Object.Basis); //  1 - Description
			ProductsTableRow.Add("");					   //  2 - Barcode
			ProductsTableRow.Add("");					   //  3 - SKU
			ProductsTableRow.Add(SectionNumber);			   //  4 - Department number
			ProductsTableRow.Add(Object.DocumentAmount);  //  5 - Price for position without discount
			ProductsTableRow.Add(1);					   //  6 - Quantity
			ProductsTableRow.Add("");					   //  7 - Discount/markup description
			ProductsTableRow.Add(0);					   //  8 - Amount of a discount/markup
			ProductsTableRow.Add(0);					   //  9 - Discount/markup percent
			ProductsTableRow.Add(Object.DocumentAmount);  // 10 - Position amount with discount
			ProductsTableRow.Add(0);					   // 11 - Tax number (1)
			ProductsTableRow.Add(0);					   // 12 - Tax amount (1)
			ProductsTableRow.Add(0);					   // 13 - Tax percent (1)
			ProductsTableRow.Add(0);					   // 14 - Tax number (2)
			ProductsTableRow.Add(0);					   // 15 - Tax amount (2)
			ProductsTableRow.Add(0);					   // 16 - Tax percent (2)
			ProductsTableRow.Add("");					   // 17 - Section name of commodity string formatting
			
			ProductsTable.Add(ProductsTableRow);
			
			// Prepare the payments table.
			PaymentsTable = New Array();
			
			PaymentRow = New ValueList();
			PaymentRow.Add(0);
			PaymentRow.Add(Object.DocumentAmount);
			PaymentRow.Add("");
			PaymentRow.Add("");
			
			PaymentsTable.Add(PaymentRow);
			
			// Prepare the general parameters table.
			CommonParameters = New Array();
			CommonParameters.Add(0);						//  1 - Receipt type
			CommonParameters.Add(True);				//  2 - Fiscal receipt sign
			CommonParameters.Add(Undefined);			//  3 - Print on lining document
			CommonParameters.Add(Object.DocumentAmount); //  4 - Amount by receipt without discounts/markups
			CommonParameters.Add(Object.DocumentAmount); //  5 - Amount by receipt with accounting all discounts/markups
			CommonParameters.Add("");					//  6 - Discount card number
			CommonParameters.Add("");					//  7 - Header text
			CommonParameters.Add("");					//  8 - Footer text
			CommonParameters.Add(0);						//  9 - Session number (for receipt copy)
			CommonParameters.Add(0);						// 10 - Receipt number (for receipt copy)
			CommonParameters.Add(0);						// 11 - Document No (for receipt copy)
			CommonParameters.Add(0);						// 12 - Document date (for receipt copy)
			CommonParameters.Add("");					// 13 - Cashier name (for receipt copy)
			CommonParameters.Add("");					// 14 - Cashier password
			CommonParameters.Add(0);						// 15 - Template number
			CommonParameters.Add("");					// 16 - Section name header format
			CommonParameters.Add("");					// 17 - Section name cellar format
			
			InputParameters.Add(ProductsTable);
			InputParameters.Add(PaymentsTable);
			InputParameters.Add(CommonParameters);
			
			// Print receipt.
			Result = EquipmentManagerClient.RunCommand(
				DeviceIdentifier,
				"PrintReceipt",
				InputParameters,
				Output_Parameters
			);
			
			If Result Then
				
				// Set the received value of receipt number to document attribute.
				Object.ReceiptCRNumber = Output_Parameters[1];
				Modified = True;
				Write(New Structure("WriteMode", DocumentWriteMode.Posting));
				
			Else
				MessageText = NStr("en='When printing a receipt, an error occurred.
									|Receipt is not printed on the fiscal register.
									|Additional
									|description: %AdditionalDetails%';ru='При печати чека произошла ошибка.
									|Чек не напечатан на фискальном регистраторе.
									|Дополнительное
									|описание: %AdditionalDetails%'");
				MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
			
			// Disable FR.
			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
			
		Else
			
			MessageText = NStr("en='An error occurred when connecting the device.
								|Receipt is not printed on the fiscal register.
								|Additional
								|description: %AdditionalDetails%';ru='При подключении устройства произошла ошибка.
								|Чек не напечатан на фискальном регистраторе.
								|Дополнительное
								|описание: %AdditionalDetails%'");
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure Pick(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en='Specify the counterparty first.';ru='Укажите вначале контрагента!'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en='Specify currency first.';ru='Укажите вначале валюту!'"));
		Return;
	EndIf;
	
	AddressPaymentDetailsInStorage = PlacePaymentDetailsToStorage();
	
	SelectionParameters = New Structure(
		"AddressPaymentDetailsInStorage,
		|SubsidiaryCompany,
		|Date,
		|Counterparty,
		|Ref,
		|OperationKind,
		|CashCurrency,
		|DocumentAmount",
		AddressPaymentDetailsInStorage,
		SubsidiaryCompany,
		Object.Date,
		Object.Counterparty,
		Object.Ref,
		Object.OperationKind,
		Object.CashCurrency,
		Object.DocumentAmount
	);
	
	Result = Undefined;
	
	OpenForm("CommonForm.CustomerDebtsPickForm", SelectionParameters,,,,, New NotifyDescription("SelectionEnd", ThisObject, New Structure("AddressPaymentDetailsInStorage", AddressPaymentDetailsInStorage)));
	
EndProcedure

&AtClient
Procedure SelectionEnd(Result, AdditionalParameters) Export
	
	AddressPaymentDetailsInStorage = AdditionalParameters.AddressPaymentDetailsInStorage;
	
	If Result = DialogReturnCode.OK Then
		
		GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage);
		TabularSectionName = "PaymentDetails";
		For Each RowPaymentDetails IN Object.PaymentDetails Do
			If Not ValueIsFilled(RowPaymentDetails.VATRate) Then
				RowPaymentDetails.VATRate = DefaultVATRate;
			EndIf;
			CalculatePaymentSUM(RowPaymentDetails);
		EndDo;
		
		SetCurrentPage();
		
		If Object.PaymentDetails.Count() = 1 Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
		EndIf;
		
	EndIf;

EndProcedure // Selection()

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined,NStr("en='Basis document is not selected.';ru='Не выбран документ основание!'"));
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en='The  document will be fully filled out according to the ""Basis"". Continue?';ru='Документ будет полностью перезаполнен по ""Основанию""! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		FillByDocument(Object.BasisDocument);
		
		If Object.PaymentDetails.Count() = 0 Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind = Object.OperationKind;
		CashCurrency = Object.CashCurrency;
		DocumentDate = Object.Date;
		
		SetChoiceParameterLinksAvailableTypes();
		SetCurrentPage();
		
	EndIf;

EndProcedure // FillByBasis()

// Procedure - FillDetails command handler.
//
&AtClient
Procedure FillDetails(Command)
	
	If Object.DocumentAmount = 0 Then
		ShowMessageBox(Undefined,NStr("en='Specify amount of document first.';ru='Укажите вначале сумму документа.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en='Specify currency first.';ru='Укажите вначале валюту!'"));
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillDetailsEnd", ThisObject), 
		NStr("en='Decryption will be completely refilled. Continue?';ru='Расшифровка будет полностью перезаполнена. Продолжить?'"),
		QuestionDialogMode.YesNo
	);
	
EndProcedure

&AtClient
Procedure FillDetailsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.PaymentDetails.Clear();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromCustomer") Then
		
		FillPaymentDetails();
		
	EndIf;
	
	SetCurrentPage();

EndProcedure // FillDetails()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
	If Not ValueIsFilled(Object.AcceptedFrom) Then
		Object.AcceptedFrom = StructureData.CounterpartyDescriptionFull;
	EndIf;
	
	If Object.PaymentDetails.Count() = 1 Then 
		
		Object.PaymentDetails[0].Contract = StructureData.Contract;
		
		If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
			Object.PaymentDetails[0].ExchangeRate = ?(
				StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.ExchangeRate
			);
			Object.PaymentDetails[0].Multiplicity = ?(
				StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Multiplicity
			);
		EndIf;
		
		Object.PaymentDetails[0].ExchangeRate = ?(
			Object.PaymentDetails[0].ExchangeRate = 0,
			1,
			Object.PaymentDetails[0].ExchangeRate
		);
		Object.PaymentDetails[0].Multiplicity = ?(
			Object.PaymentDetails[0].Multiplicity = 0,
			1,
			Object.PaymentDetails[0].Multiplicity
		);
		
		Object.PaymentDetails[0].SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
			Object.PaymentDetails[0].PaymentAmount,
			ExchangeRate,
			Object.PaymentDetails[0].ExchangeRate,
			Multiplicity,
			Object.PaymentDetails[0].Multiplicity
		);
		
	EndIf;
	
EndProcedure // CounterpartyOnChange()

// Procedure - event handler OperationKindOnChange.
// Manages pages while changing document operation kind.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	
	If OperationKind <> TypeOfOperationsBeforeChange Then
		SetCurrentPage();
		ClearAttributesNotRelatedToOperation();
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer();
		If Object.PaymentDetails.Count() = 1 Then
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
	EndIf;
	
EndProcedure // OperationKindOnChange()

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		MessageText = NStr("en='Cash fund exchange rate is changed. Recalculate the document amounts?';ru='Изменился курс валюты кассы. Пересчитать суммы документа?'");
		RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
	EndIf;
	
EndProcedure // DateOnChange()

// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	SubsidiaryCompany = StructureData.SubsidiaryCompany;
	
EndProcedure // CompanyOnChange()

// Procedure - OnChange event handler of
// the Currency input field Recalculates the PaymentDetails tabular section.
//
&AtClient
Procedure CashAssetsCurrencyOnChange(Item)
	
	CurrencyCashBeforeChanging = CashCurrency;
	CashCurrency = Object.CashCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	StructureData = GetDataCashAssetsCurrencyOnChange(
		Object.Date,
		Object.CashCurrency
	);
	
	MessageText = NStr("en='Recalculate document amounts?';ru='Пересчитать суммы документа?'");
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
	
EndProcedure // CashAssetsCurrencyOnChange()

// Procedure - OnChange event handler of the AdvanceHolder input field.
// Clears the AdvanceHolderPayments document.
//
&AtClient
Procedure AdvanceHolderOnChange(Item)
	
	If Not ValueIsFilled(Object.AcceptedFrom) Then
		StructureData = GetDataAdvanceHolderOnChange(Object.AdvanceHolder);
		Object.AcceptedFrom = StructureData.AdvanceHolderDescription;
	EndIf;
	
EndProcedure // AdvanceHolderOnChange()

// Procedure - OnChange event handler of the DocumentAmount input field.
//
&AtClient
Procedure DocumentAmountOnChange(Item)
	
	If Object.PaymentDetails.Count() = 1 Then
	
		TabularSectionRow = Object.PaymentDetails[0];
		
		TabularSectionRow.PaymentAmount = Object.DocumentAmount;
		TabularSectionRow.ExchangeRate = ?(
			TabularSectionRow.ExchangeRate = 0,
			1,
			TabularSectionRow.ExchangeRate
		);
		
		TabularSectionRow.Multiplicity = ?(
			TabularSectionRow.Multiplicity = 0,
			1,
			TabularSectionRow.Multiplicity
		);
		
		TabularSectionRow.SettlementsAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.PaymentAmount,
			ExchangeRate,
			TabularSectionRow.ExchangeRate,
			Multiplicity,
			TabularSectionRow.Multiplicity
		);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		CalculateVATSUM(TabularSectionRow);
		
	EndIf;
	
	CalculateAccountingAmount();
	
EndProcedure // DocumentAmountOnChange()

// Procedure - OnChange event handler of the CashCR input field.
//
&AtClient
Procedure CashCROnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	
EndProcedure // CashCROnChange()

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	
EndProcedure // StructuralUnitOnChange()

// Procedure - OnChange event handler of the VATTaxation input field.
//
&AtClient
Procedure VATTaxationOnChange(Item)
	
	FillVATRateByVATTaxation();
	
EndProcedure // VATTaxationOnChange()

// Procedure - OnChange event handler of the PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	Object.CashCurrency = ?(
		ValueIsFilled(Object.CashCurrency),
		Object.CashCurrency,
		GetPettyCashAccountingCurrencyAtServer(Object.PettyCash)
	);
	
EndProcedure // PettyCashOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

// Procedure - BeforeDeletion event handler of PaymentDetails tabular section.
//
&AtClient
Procedure PaymentDetailsBeforeDelete(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure // PaymentDetailsBeforeDelete()

// Procedure - OnChange event handler of the PaymentDetailsContract input field.
// Sets exchange rate and unit conversion factor of the contract currency.
//
&AtClient
Procedure PaymentDetailsContractOnChange(Item)
	
	ProcessCounterpartyContractChange();
	
EndProcedure // PaymentDetailsContractOnChange()

// Procedure - SelectionStart event handler of the PaymentDetailsContract input field.
// Sets exchange rate and unit conversion factor of the contract currency.
//
&AtClient
Procedure PaymentDetailsContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	ProcessStartChoiceCounterpartyContract(Item, StandardProcessing);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsSettlementsKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentDetailsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromCustomer") Then
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromVendor") Then
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashPayment")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
			TabularSectionRow.AdvanceFlag = True;
			ShowMessageBox(Undefined,NStr("en='The Advance check box is always selected for this document type.';ru='Для данного типа документа расчетов признак аванса всегда установлен!'"));
		ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.Netting") Then
			TabularSectionRow.AdvanceFlag = False;
			ShowMessageBox(Undefined,NStr("en='Cannot select the Advance check box for this type of settlements document.';ru='Для данного типа документа расчетов нельзя установить признак аванса!'"));
		EndIf;
	EndIf;
	
EndProcedure // PaymentDetailsAdvanceFlagOnChange()

// Procedure - SelectionStart event handler of the PaymentDetailsDocument input field.
// Passes the current attribute value to the parameters.
//
&AtClient
Procedure PaymentDetailsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If TabularSectionRow.AdvanceFlag
		AND Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromCustomer") Then
		
		ShowMessageBox(, NStr("en='The current document is a document of settlements for the calculation kind ""Advance"".';ru='Для вида расчета с признаком ""Аванс"" документом расчетов будет текущий!'"));
		
	Else
		
		ThisIsAccountsReceivable = OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromCustomer");
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Counterparty", Object.Counterparty);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureFilter.Insert("Contract", TabularSectionRow.Contract);
		EndIf;
		
		ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
			StructureFilter,
			ThisIsAccountsReceivable,
			TypeOf(Object.Ref)
		);
		
		OpenForm("CommonForm.SettlementsDocumentChoiceForm", ParameterStructure, Item);
		
	EndIf;
	
EndProcedure // PaymentDetailsDocumentSelectionStart()

// Procedure - SelectionDataProcessor event handler of the PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(ValueSelected);
	
EndProcedure

// Procedure - OnChange event handler of the field in PaymentDetailsSettlementsAmount.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsSettlementsAmountOnChange(Item)
	
	CalculatePaymentSUM(Items.PaymentDetails.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure // PaymentDetailsSettlementsAmountOnChange()

// Procedure - OnChange event handler of the PaymentDetailsExchangeRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRateOnChange(Item)
	
	CalculatePaymentSUM(Items.PaymentDetails.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure // PaymentDetailsRateOnChange()

// Procedure - OnChange event handler of the PaymentDetailsUnitConversionFactor input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRepetitionOnChange(Item)
	
	CalculatePaymentSUM(Items.PaymentDetails.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure // PaymentDetailsUnitConversionFactorOnChange()

// Procedure - OnChange event handler of the PaymentDetailsPaymentAmount input field.
// Calculates exchange rate and unit conversion factor of the settlements currency and VAT amount.
//
&AtClient
Procedure PaymentDetailsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.SettlementsAmount = 0,
		1,
		TabularSectionRow.PaymentAmount / TabularSectionRow.SettlementsAmount * ExchangeRate
	);
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure // PaymentDetailsPaymentAmountOnChange()

// Procedure - OnChange event handler of the PaymentDetailsVATRate input field.
// Calculates VAT amount.
//
&AtClient
Procedure PaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure // PaymentDetailsVATRateOnChange()

// Procedure - OnChange event handler of the PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentOnChange(Item)
	
	RunActionsOnAccountsDocumentChange();
	
EndProcedure // PaymentDetailsDocumentOnChange() 

// Procedure - OnChange event handler of the RetailIncomePaymentDetailsVATRate input field.
//
&AtClient
Procedure RetailIncomePaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.RetailIncomePaymentDetails.CurrentData;
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure // RetailIncomePaymentDetailsVATRateOnChange()

// Procedure - OnChange event handler of the CurrencyPurchaseRate input field.
//
&AtClient
Procedure CurrencyPurchaseRateOnChange(Item)
	
	CalculateAccountingAmount();
	
EndProcedure // CalculateAccountingAmount()

// Procedure - OnChange event handler of the CurrencyPurchaseRepetition input field.
//
&AtClient
Procedure CurrencyPurchaseRepetitionOnChange(Item)
	
	CalculateAccountingAmount();
	
EndProcedure // CalculateAccountingAmount()

// Procedure - OnChange event handler of the CurrencyPurchaseAccountingAmount input field.
//
&AtClient
Procedure CurrencyPurchaseAccountingAmountOnChange(Item)
	
	Object.ExchangeRate = ?(
		Object.ExchangeRate = 0,
		1,
		Object.ExchangeRate
	);
	
	Object.Multiplicity = ?(
		Object.Multiplicity = 0,
		1,
		Object.Multiplicity
	);
	
	Object.ExchangeRate = ?(
		Object.DocumentAmount = 0,
		1,
		Object.AccountingAmount / Object.DocumentAmount * AccountingCurrencyRate
	);
	
EndProcedure // CurrencyPurchaseAccountingAmountOnChange()

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

#Region InteractiveActionResultHandlers

// Procedure-handler of a result of the question on document amount recalculation. 
//
//
&AtClient
Procedure DetermineNeedForDocumentAmountRecalculation(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		If Object.PaymentDetails.Count() > 0 Then
			If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromCustomer")
			 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.FromVendor") Then
				RecalculateDocumentAmounts(ExchangeRate, Multiplicity, True);
			Else
				DocumentAmountIsEqualToTotalPaymentAmount = Object.PaymentDetails.Total("PaymentAmount") = Object.DocumentAmount;
				
				For Each TabularSectionRow IN Object.PaymentDetails Do // recalculate plan amount for the operations with planned payments.
					TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
						TabularSectionRow.PaymentAmount,
						AdditionalParameters.ExchangeRateBeforeChange,
						ExchangeRate,
						AdditionalParameters.MultiplicityBeforeChange,
						Multiplicity
					);
				EndDo;
					
				If DocumentAmountIsEqualToTotalPaymentAmount Then
					Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
				Else
					Object.DocumentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
						Object.DocumentAmount,
						AdditionalParameters.ExchangeRateBeforeChange,
						ExchangeRate,
						AdditionalParameters.MultiplicityBeforeChange,
						Multiplicity
					);
				EndIf;
				
			EndIf;
		Else
			Object.DocumentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				Object.DocumentAmount,
				AdditionalParameters.ExchangeRateBeforeChange,
				ExchangeRate,
				AdditionalParameters.MultiplicityBeforeChange,
				Multiplicity
			);
		EndIf;
		
	Else
		
		If Object.PaymentDetails.Count() > 0 Then
			RecalculateDocumentAmounts(ExchangeRate, Multiplicity, False);
		EndIf;
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCashReceipt.CurrencyPurchase") Then
		CalculateAccountingAmount();
	EndIf;
	
EndProcedure // DetermineNeedForDocumentFillByBasis()

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm);
	
EndProcedure // UpdateAdditionalAttributeItems()

// End StandardSubsystems.Properties

#EndRegion