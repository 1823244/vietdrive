﻿////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Imports the form settings.
// If settings are imported during form attribute
// change, for example for new company, it shall be checked
// whether extension for file handling is enabled.
//
// Data in attributes of the processed object will be a flag of connection failure:
// ExportFile, ImportFile
//
&AtServer
Procedure ImportFormSettings()
	
	Settings = SystemSettingsStorage.Load("DataProcessor.ClientBank.Form.DefaultForm/" + GetURL(Object.BankAccount), "ExportingInClientbank");
	
	If Settings <> Undefined Then
		
		Object.ExternalDataProcessor = Settings.Get("ExternalDataProcessor");
		Object.Encoding = Settings.Get("Encoding");
		Object.FormatVersion = Settings.Get("FormatVersion");
		If Not ValueIsFilled(Object.Encoding) Then
			Object.Encoding = "ANSI";
		EndIf;
		If Not ValueIsFilled(Object.FormatVersion) Then
			Object.FormatVersion = "1.02";
		EndIf;
		
	EndIf;
	
EndProcedure // ImportFormSettings()

// Function checks the correctness of the form attribute filling.
//
&AtClient
Function CheckFillOfFormAttributes()
	
	CheckResultOk = True;
	
	// Attributes filling check.
	If Not ValueIsFilled(Object.StartPeriod) Then
		MessageText = NStr("en='Beginning period is required.';ru='Не заполнен начальный период!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "StartPeriod", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.EndPeriod) Then
		MessageText = NStr("en='End period is required.';ru='Не заполнен конечный период!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "EndPeriod", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.Company) Then
		MessageText = NStr("en='Company is required.';ru='Не заполнена организация!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "Company", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.BankAccount) Then
		MessageText = NStr("en='Bank account is required.';ru='Не заполнен банковский счет!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "BankAccount", CheckResultOk);
	EndIf;
	
	If Not ValueIsFilled(Object.ExternalDataProcessor) Then
		MessageText = NStr("en='Receiver Data Processor is not filled out.';ru='Не заполнена обработка приемник!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "ExternalDataProcessor", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.Encoding) Then
		MessageText = NStr("en='Encoding is required.';ru='Не заполнена кодировка!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "Encoding", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.FormatVersion) Then
		MessageText = NStr("en='Exchange format version not specified.';ru='Не указана версия формата обмена!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "FormatVersion", CheckResultOk);
	EndIf;
	
	Return CheckResultOk;
	
EndFunction // CheckFillFormAttributes()

// Function checks the data correctness for export.
//
&AtServer
Function CheckForCorrectnessAndBlankExportValue(DocumentRow)
	
	TaxTransfer          = False;
	PayerIndirectPayments = False;
	RecipientIndirectSettlements  = False;
	TaxTransfer          = (DocumentRow.OperationKind = Enums.OperationKindsPaymentOrder.TaxTransfer);
	PayerIndirectPayments = ValueIsFilled(DocumentRow.CompanySettlementsBank);
	RecipientIndirectSettlements  = ValueIsFilled(DocumentRow.CounterpartySettlementsBank);
	Payer = "Company";
	Recipient = "Counterparty";
	AttributesPaymentDocumentExportBasic = "Number,Date,DocumentAmount";
	AttributesPaymentDocumentExportPayer = Payer + "Account," + Payer + "," + Payer + "TIN";
	AttributesPaymentDocumentExportTNRPayer = Payer + "BankAccount," + Payer + "SettlementBank," + Payer + "BankCity," + Payer + "BankPCBIC";
	AttributesPaymentDocumentExportRecipient = Recipient + "Account," + Recipient + "," + Recipient + "TIN";
	AttributesPaymentDocumentExportTNRRecipient = Recipient + "BankAccount," + Recipient + "SettlementBank," + Recipient + "BankCity," + Recipient + "BankPCBIC";
	AttributesExDockPlBudgetPayment = "AuthorStatus,PayerRegistrationNumber,PayeeRegistrationNumber,BasisIndicator,PeriodIndicator,NumberIndicator,DateIndicator,TypeIndicator";
	
	StringAttributes = "%AttributesPaymentDocumentExportBasic%,%AttributesPaymentDocumentExportPayer%,%AttributesPaymentDocumentExportTNRPayer%%AttributesPaymentDocumentExportRecipient%,%AttributesPaymentDocumentExportTNRRecipient%";
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportBasic%", AttributesPaymentDocumentExportBasic);
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportPayer%", AttributesPaymentDocumentExportPayer);
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportTNRPayer%", ?(PayerIndirectPayments, AttributesPaymentDocumentExportTNRPayer + ",", ""));
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportRecipient%", AttributesPaymentDocumentExportRecipient);
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportTNRRecipient%", ?(RecipientIndirectSettlements, AttributesPaymentDocumentExportTNRRecipient + ",", ""));
	
	ExportIsNotEmpty = CreateMapFromString(StringAttributes);
	
	For Each Property IN ExportIsNotEmpty Do
		CheckForBlankExportValue(DocumentRow, Property.Key);
	EndDo;
	If TaxTransfer Then
		CheckTaxAttributesFill(DocumentRow);
	EndIf;
	CheckForCorrectionNumbernessOnDump(DocumentRow);
	
EndFunction // CheckForCorrectnessAndBlankExportValue()

// Procedure checks the blank data value for export.
//
&AtServer
Procedure CheckForBlankExportValue(RowExporting, PropertyName)
	
	If Not ValueIsFilled(RowExporting[TrimAll(PropertyName)]) Then
		RowRemark = NStr("en='""%PropertyName%"" is not filled!';ru='Не заполнено ""%PropertyName%""!'");
		RowRemark = StrReplace(RowRemark, "%PropertyName%", PropertyName);
		AddComment(RowExporting, 3, RowRemark);
		SetReadiness(RowExporting.Readiness, 4);
	EndIf;
	
EndProcedure // CheckForBlankExportValue()

// Procedure checks the number correctness for export.
//
&AtServer
Procedure CheckForCorrectionNumbernessOnDump(RowExporting)
	
	Value = TrimAll(RowExporting.Number);
	Try
		If Number(String(Number(Right(Value, 3)))) = 0 Then
			AddComment(RowExporting, 4, NStr("en='Number should end with three digits which are not ""000"".';ru='Номер должен оканчиваться на три цифры и не на ""000""!'"));
		EndIf;
	Except
		AddComment(RowExporting, 4, NStr("en='Number should end with three digits which are not ""000"".';ru='Номер должен оканчиваться на три цифры и не на ""000""!'"));
	EndTry;
	
EndProcedure // CheckForCorrectionNumbernessOnExport()

// Function checks the correctness of the tax attribute filling.
//
&AtServer
Function CheckTaxAttributesFill(RowExporting)
	
	Error = New ValueList();
	P101 = TrimAll(RowExporting.AuthorStatus);
	P106 = TrimAll(RowExporting.BasisIndicator);
	P107 = ?(
		IsBlankString(TrimAll(StrReplace(RowExporting.PeriodIndicator , ".", ""))) = 1,
		"",
		RowExporting.PeriodIndicator
	);
	P107 = ?(
		TrimAll(StrReplace(RowExporting.PeriodIndicator, ".", "")) = "0",
		"",
		RowExporting.PeriodIndicator
	);
	P108 = TrimAll(RowExporting.NumberIndicator);
	P109 = ?(
		Not ValueIsFilled(RowExporting.DateIndicator),
		"0",
		String(RowExporting.DateIndicator)
	);
	P110 = TrimAll(RowExporting.TypeIndicator);
	If (Find("01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26", P101) = 0)
	 OR (IsBlankString(TrimAll(P101))) Then
		AddComment(
			RowExporting,
			3,
			NStr("en='Invalid value of the ""Author status"" attribute value for payments to budget on the ""Funds transfer to budget"" tab.';ru='Неверное значение поля реквизита для платежей в бюджет ""Статус составителя"" на закладке ""Перечисление в бюджет"".'")
		);
		SetReadiness(RowExporting.Readiness, 4);
	EndIf;
	
	// We check it depending on preparer status.
	If P101 = "08" Then
		If StrReplace(P106, "0", "") <> "" Then 
			AddComment(
				RowExporting,
				3,
				NStr("en='If the author status is ""08"", specify ""0"" in the ""Payment purpose"" field on the ""Funds transfer to budget"" tab.';ru='При статусе составителя ""08"" следует указать ""0"" в поле ""Основание платежа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P107, "0", "") <> "" Then
			AddComment(
				RowExporting,
				3,
				NStr("en='If the author status is ""08"", specify ""0"" in the ""Fiscal period"" field on the ""Funds transfer to budget"" tab.';ru='При статусе составителя ""08"" следует указать ""0"" в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P108, "0", "") <> "" Then
			AddComment(
				RowExporting,
				3,
				NStr("en='If the author status is ""08"", the ""Document number"" field on the ""Funds transfer to budget"" tab should be empty.';ru='При статусе составителя ""08"" не следует заполнять поле ""Номер документа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P109, "0", "") <> "" Then
			AddComment(
				RowExporting,
				3,
				NStr("en='If the author status is ""08"", the ""Document date"" field on the ""Funds transfer to budget"" tab should be empty.';ru='При статусе составителя ""08"" не следует заполнять поле ""Дата документа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P110, "0", "") <> "" Then
			AddComment(
				RowExporting,
				3,
				NStr("en='If the author status is ""08"", specify ""0"" in the ""Payment type"" field on the ""Funds transfer to budget"" tab.';ru='При статусе составителя ""08"" следует указать ""0"" в поле ""Тип платежа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
	Else
		// We check depending on the payment basis.
		If StrReplace(TrimAll(P106), "0", "") = "" Then
			If StrReplace(P107, "0", "") <> "" Then
				If Not ValueIsFilled(P107) Then
					AddComment(
						RowExporting,
						3,
						NStr("en='The ""Tax period"" field value on the ""Funds transfer to budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
					);
					SetReadiness(RowExporting.Readiness, 4);
				EndIf;
			EndIf;
		ElsIf StrLen(P106) <> 2 Then
			If StrReplace(P107, "0", "") <> "" Then
				If Not ValueIsFilled(P107) Then
					AddComment(
						RowExporting,
						3,
						NStr("en='The ""Tax period"" field value on the ""Funds transfer to budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
					);
					SetReadiness(RowExporting.Readiness, 4);
				EndIf;
			EndIf;
		ElsIf Find("AP, AR", P106) > 0 Then
			If StrReplace(P107, "0", "") <> "" Then
				AddComment(
					RowExporting,
					3,
					NStr("en='If the payment basis is ""AA"" or ""EA"", specify ""0"" in the ""Fiscal period"" field on the ""Funds transfer to budget"" tab.';ru='При основании платежа ""АП"" или ""АР"" следует указать ""0"" в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
				);
				SetReadiness(RowExporting.Readiness, 4);
			EndIf;
		ElsIf Find("TP, RS, OT, PT, VU, PR, PB, ZT, IN", P106) > 0 Then
			If StrReplace(P107, "0", "") <> "" Then
				If Not ValueIsFilled(P107) Then
					AddComment(
						RowExporting,
						3,
						NStr("en='The ""Tax period"" field value on the ""Funds transfer to budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
					);
					SetReadiness(RowExporting.Readiness, 4);
				EndIf;
			EndIf;
		ElsIf Find("CP, ZD ", P106) > 0 Then
			If StrReplace(P107, "0", "") <> "" Then
				DD = Mid((P107), 1, 2);
				MM = Mid((P107), 4, 2);
				yy = Mid((P107), 7, 4);
				If Not MM = "" Then
					MM = Number(Mid((P107), 4, 2));
				Else
					MM = 0;
				EndIf;
				If Not yy = "" Then
					yy = Number(Mid((P107), 7, 4));
				Else
					yy = 0;
				EndIf;
				If (Find("D1, D2, D3, MS", DD) > 0) Then
					If (MM < 1)
					 OR (MM > 12)
					 OR (yy < 2000)
					 OR (StrLen(P107) - StrLen(StrReplace(P107, ".", "")) <> 2) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='The ""Tax period"" field value on the ""Funds transfer to budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						);
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				ElsIf (Find("KV", DD) > 0) Then
					If (MM < 1)
					 OR (MM > 4)
					 OR (yy < 2000)
					 OR (StrLen(P107) - StrLen(StrReplace(P107, ".", "")) <> 2) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='Invalid value of the ""Tax period"" field on the ""Funds transfer to budget"" tab.';ru='Неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						);
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				ElsIf (Find("PL", DD) > 0) Then
					If (MM < 1)
					 OR (MM > 2)
					 OR (yy < 2000)
					 OR (StrLen(P107) - StrLen(StrReplace(P107, ".", "")) <> 2) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='Invalid value of the ""Tax period"" field on the ""Funds transfer to budget"" tab.';ru='Неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						);
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				ElsIf (Find("GD", DD) > 0) Then
					If (MM <> 0)
					 OR (yy < 2000)
					 OR (StrLen(P107) - StrLen(StrReplace(P107, ".", "")) <> 2) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='Invalid value of the ""Tax period"" field on the ""Funds transfer to budget"" tab.';ru='Неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						);
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				Else
					If Not ValueIsFilled(P107) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='The ""Tax period"" field value on the ""Funds transfer to budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						); 
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				EndIf;
			EndIf;
			If StrReplace(P108, "0", "") <> "" Then
				AddComment(
					RowExporting,
					3,
					NStr("en='If the payment basis is ""TP"" or ""ZD"", specify ""0"" in the ""Document number"" field on the ""Funds transfer to budget"" tab.';ru='При основании платежа ""ТП"" или ""ЗД"" необходимо указывать ""0"" в поле ""Номер документа"" на закладке ""Перечисление в бюджет"".'")
				);
				SetReadiness(RowExporting.Readiness, 4);
			EndIf;
			If Find("ZD ", P106) > 0 Then
				If StrReplace(P109, "0", "") <> "" Then
					AddComment(
						RowExporting,
						3,
						NStr("en='If the payment basis is ""ZD"", the ""Document date"" field on the ""Funds transfer to budget"" tab should be empty.';ru='При основании платежа ""ЗД"" не должно заполняться поле ""Дата документа"" на закладке ""Перечисление в бюджет"".'")
					);
					SetReadiness(RowExporting.Readiness, 4);
				EndIf;
			EndIf;
		ElsIf Find("BF, DE, PO, CC, ID, CO, TY, BD, IN, KP", P106) > 0 Then
		Else
			AddComment(
				RowExporting,
				3,
				NStr("en='Incorrect value in the ""Payment purpose"" field on the ""Funds transfer to budget"" tab.';ru='Неверно указано значение в поле ""Основание платежа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P110, "0", "") = "" Then
		ElsIf Find("TF, AB, PE, PC, AS, ASH, ISH, PL, GP, VZ, PCS, ZD", P110) > 0 Then
		Else
			AddComment(
				RowExporting,
				3,
				NStr("en='Incorrect value in the ""Payment type"" field on the ""Funds transfer to budget"" tab.';ru='Неверно указано значение в поле ""Тип платежа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
	EndIf;
	
	// We are displaying a found error list.
	For Num = 0 To Error.Count() - 1 Do
		MessageText = Error.Get(Num);
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
	EndDo;
	
	Return Error;
	
EndFunction // CheckTaxAttributesFill()

// Procedure checks sets readiness.
//
&AtServer
Procedure SetReadiness(CurrentReadiness, NewReadiness)
	
	If ValueIsFilled(CurrentReadiness)
	   AND CurrentReadiness < NewReadiness Then
		CurrentReadiness = NewReadiness;
	ElsIf Not ValueIsFilled(CurrentReadiness) Then
		CurrentReadiness = NewReadiness;
	EndIf;
	
EndProcedure // SetReadiness()

// Procedure adds a comment.
//
&AtServer
Procedure AddComment(DocumentStructure, NewReadiness, NoticeText)
	
	SetReadiness(DocumentStructure.Readiness, NewReadiness);
	AddToString(DocumentStructure.ErrorsDescriptionFull, NoticeText);
	
EndProcedure // AddComment()

// Procedure adds a row.
//
&AtServer
Procedure AddToString(Buffer, NewRow)
	
	If IsBlankString(Buffer) Then
		Buffer = NewRow;
	Else
		Buffer = Buffer + Chars.LF + NewRow;
	EndIf;
	
EndProcedure // AddToString()

// Function creates a match from string.
//
&AtServer
Function CreateMapFromString(Val StringThroughComma)
	
	NewMap = New Map;
	SeparatorPosition = Find(StringThroughComma, ",");
	While SeparatorPosition > 0 Do
		NameItema = Left(StringThroughComma, SeparatorPosition - 1);
		NewMap.Insert(NameItema, True);
		StringThroughComma = Mid(StringThroughComma, SeparatorPosition + 1);
		SeparatorPosition = Find(StringThroughComma, ",");
	EndDo;
	If StrLen(StringThroughComma) > 0 Then
		NewMap.Insert(StringThroughComma, True);
	EndIf;
	
	Return NewMap;
	
EndFunction // CreateMatchFromString()

// Procedure fills out a table for exporting.
//
&AtServer
Procedure FillDump()
	
	Object.Company = Object.BankAccount.Owner;
	
	Query = New Query(
	"SELECT
	|	PaymentOrder.Date,
	|	PaymentOrder.Number,
	|	PaymentOrder.PaymentDestination,
	|	PaymentOrder.PaymentKind,
	|	PaymentOrder.Ref AS Document,
	|	PaymentOrder.AuthorStatus,
	|	PaymentOrder.DocumentAmount,
	|	PaymentOrder.Counterparty,
	|	PaymentOrder.OperationKind,
	|	PaymentOrder.PaymentPriority,
	|	PaymentOrder.PayerText,
	|	PaymentOrder.PayeeText,
	|	PaymentOrder.PayerTIN AS PayerTIN,
	|	PaymentOrder.PayeeTIN AS PayeeTIN,
	|	PaymentOrder.Company.DescriptionFull AS Company,
	|	PaymentOrder.Company.TIN AS CompanyTIN,
	|	PaymentOrder.Company.RegistrationNumber AS CompanyRegistrationNumber,
	|	PaymentOrder.BankAccount AS CompanyAccount,
	|	PaymentOrder.BankAccount.AccountNo AS CompanyAccountNo,
	|	PaymentOrder.BankAccount.Bank.Code AS CompanyBankBIC,
	|	PaymentOrder.BankAccount.Bank AS CompanyBank,
	|	PaymentOrder.BankAccount.Bank.CorrAccount AS CompanyBankAcc,
	|	PaymentOrder.BankAccount.Bank.City AS CompanyBankCity,
	|	PaymentOrder.BankAccount.AccountsBank AS CompanySettlementsBank,
	|	PaymentOrder.BankAccount.AccountsBank.City AS CompanyBankProcessingCenterCity,
	|	PaymentOrder.BankAccount.AccountsBank.Code AS CompanyBankProcessingCenterBIC,
	|	PaymentOrder.BankAccount.AccountsBank.CorrAccount AS CompanyBankProcessingCenterCorrAccount,
	|	PaymentOrder.Counterparty.TIN AS CounterpartyTIN,
	|	PaymentOrder.Counterparty.RegistrationNumber AS CounterpartyRegistrationNumber,
	|	PaymentOrder.CounterpartyAccount AS CounterpartyAccount,
	|	PaymentOrder.CounterpartyAccount.AccountNo AS CounterpartyAccountNo,
	|	PaymentOrder.CounterpartyAccount.Bank AS CounterpartyBank,
	|	PaymentOrder.CounterpartyAccount.Bank.CorrAccount AS CounterpartyBankAcc,
	|	PaymentOrder.CounterpartyAccount.Bank.City AS CounterpartyBankCity,
	|	PaymentOrder.CounterpartyAccount.AccountsBank AS CounterpartySettlementsBank,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.City AS CounterpartyBankProcessingCenterCity,
	|	PaymentOrder.CounterpartyAccount.Bank.Code AS CounterpartyBankBIC,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.Code AS CounterpartyBankProcessingCenterBIC,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.CorrAccount AS CounterpartyBankProcessingCenterCorrAccount,
	|	PaymentOrder.PaymentIdentifier AS PaymentIdentifier,
	|	""Payment order"" AS DocumentKind,
	|	CAST("""" AS STRING(255)) AS ErrorsDescriptionFull,
	|	0 AS Readiness,
	|	0 AS PictureNumber,
	|	0 AS DocumentAmountAllocated,
	|	TRUE AS Exporting
	|FROM
	|	Document.PaymentOrder AS PaymentOrder
	|WHERE
	|	PaymentOrder.Company = &Company
	|	AND PaymentOrder.BankAccount = &BankAccount
	|	AND PaymentOrder.Date BETWEEN &StartPeriod AND &EndPeriod
	|	AND PaymentOrder.DeletionMark = FALSE
	|
	|ORDER BY
	|	PaymentOrder.Date,
	|	Document");
	
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("BankAccount", Object.BankAccount);
	Query.SetParameter("StartPeriod", BegOfDay(Object.StartPeriod));
	Query.SetParameter("EndPeriod", EndOfDay(Object.EndPeriod));
	
	Exporting = Query.Execute().Unload();
	
	For Each DocumentRow IN Exporting Do
		CheckForCorrectnessAndBlankExportValue(DocumentRow);
		DocumentRow.Exporting = IsBlankString(DocumentRow.ErrorsDescriptionFull);
		DocumentRow.PaymentDestination = TrimAll(DocumentRow.PaymentDestination);
		DocumentRow.PictureNumber = ?(IsBlankString(DocumentRow.ErrorsDescriptionFull), 0, 1);
		FillAmountsAllocatedAtServer(DocumentRow);
	EndDo;
	
	Object.Exporting.Load(Exporting);
	
	
EndProcedure // FillExport()

// Procedure exports data to the file.
//
&AtServer
Function DonwloadDataToFile()
	
	DumpStream = FormAttributeToValue("Object").Unload(FileOperationsExtensionConnected, UUID);
	
	Return DumpStream;
	
EndFunction // ExportDataToFile()

// Function saves a swap file.
//
&AtClient
Procedure SaveExportFile(DumpStream)
	
	#If WebClient Then
		ThisIsWebClient = True;
	#Else
		ThisIsWebClient = False;
	#EndIf
	
	Try
		
		ExportOnline = Object.ExportFile = "1c_to_kl.txt" OR ThisIsWebClient;
		
		Result = GetFile(DumpStream, Object.ExportFile, ExportOnline);
		
		// We check those documents that were successfully exported.
		If Result <> Undefined Then
			If Result Then
				
				For Each SectionRow IN Object.Exporting Do
				
					If SectionRow.Readiness = - 2 Then
						SectionRow.Readiness = - 1;
					EndIf;
				EndDo;
				If ExportOnline Then
					MessageText = NStr("en='Data has been exported to the file.';ru='Данные успешно выгружены в файл.'");
				Else
					MessageText = NStr("en='Data is successfully exported to the file ';ru='Данные успешно выгружены в файл '") + Object.ExportFile + ".";
				EndIf;
			Else
				MessageText = NStr("en='Operation is canceled';ru='Операция отменена'");
			EndIf;
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	Except
		
		MessageText = NStr("en='Cannot write data to file. The disk may be write protected.';ru='Не удалось записать данные в файл. Возможно, диск защищен от записи.'");
		ShowMessageBox(Undefined,MessageText);
		
	EndTry
	
EndProcedure // SaveSwapFile()

// Procedure sets flags.
//
&AtClient
Procedure SetFlags(Table, Field, ValueOfFlag)
	
	For Each String IN Table Do
		String[Field] = ValueOfFlag;
		FillAmount76AtClient(String)
	EndDo;
	
EndProcedure // SetFlags()

// Function returns the found tree item.
//
&AtServer
Function FindTreeItem(TreeItems, ColumnName, RequiredValue)
	
	For Num = 0 To TreeItems.Count() - 1 Do
		
		TreeItem = TreeItems.Get(Num);
		
		If TreeItem[ColumnName] = RequiredValue Then
			Return TreeItem;
		EndIf;
		
		If TreeItem.GetItems().Count() > 0 Then
			
			SearchResult = FindTreeItem(TreeItem.GetItems(), ColumnName, RequiredValue);
			
			If Not SearchResult = Undefined Then
				Return SearchResult;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction // FindTreeItem()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Company") Then
		Object.Company = Parameters.Company;
	EndIf;
	
	If Parameters.Property("BankAccountOfTheCompany")
	   AND ValueIsFilled(Parameters.BankAccountOfTheCompany) Then
		Object.BankAccount = Parameters.BankAccountOfTheCompany;
		ThisForm.Title = "Saving of payment orders by bill: " + Parameters.BankAccountOfTheCompany.Description;
	Else
		Items.GroupBankAccountExport.Visible = True;
	EndIf;
	
	If Parameters.Property("ExportFile") Then
		Object.ExportFile = Parameters.ExportFile;
	EndIf;
	
	If Parameters.Property("ExternalDataProcessor") Then
		Object.ExternalDataProcessor = Parameters.ExternalDataProcessor;
	EndIf;
	
	If Parameters.Property("Encoding") Then
		Object.Encoding = Parameters.Encoding;
	EndIf;
	
	If Parameters.Property("FormatVersion") Then
		Object.FormatVersion = Parameters.FormatVersion;
	EndIf;
	
	If Not ValueIsFilled(Object.Company) Then
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Object.Company = SettingValue;
		Else
			Object.Company = Catalogs.Companies.MainCompany;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.BankAccount) Then
		Object.BankAccount = Object.Company.BankAccountByDefault;
	EndIf;
	
	If Not ValueIsFilled(Object.StartPeriod) Then
		Object.StartPeriod = CurrentDate();
	EndIf;
	
	If Not ValueIsFilled(Object.EndPeriod) Then
		Object.EndPeriod = CurrentDate();
	EndIf;
	
	If Not ValueIsFilled(Object.Encoding) Then
		Object.Encoding = "ANSI";
	EndIf;
	
	If Not ValueIsFilled(Object.FormatVersion) Then
		Object.FormatVersion = "1.02";
	EndIf;
		
	FillDump();
	ImportFormSettings();
	 	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	Notification = New NotifyDescription("BeginEnableExtensionFileOperationsEnd", ThisObject, New Structure("FormAttribute", "ImportFile"));
	BeginAttachingFileSystemExtension(Notification);
	If Not ValueIsFilled(Object.ExportFile) Then
		Object.ExportFile = "1c_to_kl.txt";
	EndIf;
	
EndProcedure // OnOpen()

&AtClient
Procedure BeginEnableExtensionFileOperationsEnd(Attached, AdditionalParameters) Export
	
	ThisForm.FileOperationsExtensionConnected = Attached;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - Export command handler.
//
&AtClient
Procedure ExportExecute(Command)
	
	ClearMessages();
	
	If Not CheckFillOfFormAttributes() Then
		
		Return;
		
	EndIf;
	
	If Object.Exporting.Count() > 0 Then
		
		//( elmi #17 (112-00003) 
		//AT ExternalDataProcessorRefs = GetExternalDataProcessor(Object.BankAccount);
		//ExternalDataProcessorRefs = Object.DataProcessor;
		//
		//If ValueIsFilled(ExternalDataProcessorRefs) Then
		//  
		//	ArrayOfPurposes  = New  Array;
		//    ArrayOfPurposes.Insert(0, Object.BankAccount); 

		//	ExportArray  =  PutToTempStorage(UpLoadTSExporting(), UUID);
		//	
		//	ParametersOfDataProcessor = New Structure("CommandID, AdditionalInformationProcessorRef, ArrayOfPurposes, ExportArray, ExecutionResult" ); 
		//    ParametersOfDataProcessor.CommandID                           = "ExportFromClientBankExternalDP";
		//    ParametersOfDataProcessor.AdditionalInformationProcessorRef   = ExternalDataProcessorRefs;
		//    ParametersOfDataProcessor.ArrayOfPurposes                     = Object.BankAccount;
		//    ParametersOfDataProcessor.ExportArray                         = ExportArray;
		//    ParametersOfDataProcessor.ExecutionResult                     = New Structure("ExportAddress, WarningText" );
		//	
		//	RunCommandOnServer( ParametersOfDataProcessor);
		//	
		//	WarningText = "";
		//    Result = ParametersOfDataProcessor.ExecutionResult;
		//
		//	If Result <> Undefined Then
		//		If ValueIsFilled(Result.WarningText) Then
		//		   WarningText = Result.WarningText;
		//		Else	
		//			If ValueIsFilled(Result.ExportAddress)  Тогда 
		//				SaveExportFile(Result.ExportAddress);
		//			Else
		//				WarningText = НСтр("en = 'Error in data export!',ru='Ошибка в данных экспорта!'");
		//			EndIF;	
		//		EndIF;		
		//	Else	  
		//		WarningText = NStr("en='Export document list is empty.
		//|Verify the correctness of the specified banking account and the export period.';ru='Список документов для выгрузки пуст.
		//|Проверьте правильность указанного банковского счета и периода выгрузки.'");
		//	EndIf;
		//	
		//	If ValueIsFilled(WarningText) Then
		//  		ShowMessageBox(Undefined,WarningText);
		//    EndIf;
		////) elmi
		//
		//Else 
	    	DumpStream = DonwloadDataToFile();
			If DumpStream <> Undefined Then
		    	SaveExportFile(DumpStream);
			EndIf;
		//EndIf;	
	Else
		
		ShowMessageBox(Undefined,
			NStr("en='Export document list is empty.
		|Verify the correctness of the specified banking account and the export period.';ru='Список документов для выгрузки пуст.
		|Проверьте правильность указанного банковского счета и периода выгрузки.'")
		);
		
	EndIf;
			
EndProcedure // ExportExecute()


// Procedure - ExportRefresh command handler.
//
&AtClient
Procedure DumpUpdateRun(Command)
	
	FillDump();
	
EndProcedure // ExportRefreshExecute()

// Procedure - ExportCheckAll command handler.
//
&AtClient
Procedure DumpMarkAllRun(Command)
	
	SetFlags(Object.Exporting, "Exporting", True);
	
EndProcedure // ExportMarkAllRun()

// Procedure - ExportUncheckAll command handler.
//
&AtClient
Procedure DumpUnmarkAllRun(Command)
	
	SetFlags(Object.Exporting, "Exporting", False);
	
EndProcedure // ExportUnmarkAllRun()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - Open event handler of the BankAccount input field.
//
&AtClient
Procedure BankAccountOnChange(Item)
	
	FillDump();
	ImportFormSettings();
	
EndProcedure // BankAccountOnChange()

// Procedure - Open event handler of the StartPeriod input field.
//
&AtClient
Procedure StartPeriodOnChange(Item)
	
	FillDump();
	
EndProcedure // StartPeriodOnChange()

// Procedure - Open event handler of the EndPeriod input field.
//
&AtClient
Procedure EndPeriodOnChange(Item)
	
	FillDump();
	
EndProcedure // EndPeriodOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTIONS EVENT HANDLERS

// Procedure - Selection event handler of the export tabular section .
//
&AtClient
Procedure ExportSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Field.Name = "ExportExporting" Then
		Items.Exporting.CurrentData.Exporting = Not (Items.Exporting.CurrentData.Exporting);		
	ElsIf Field.Name = "ExportPictureNumber" Then 
		If ValueIsFilled(Items.Exporting.CurrentData.ErrorsDescriptionFull) Then
			ShowMessageBox(Undefined,Items.Exporting.CurrentData.ErrorsDescriptionFull);
		Else
			ShowMessageBox(Undefined,NStr("en='Document is ready for export.';ru='Документ готов к выгрузке!'"));
		EndIf;
	ElsIf Field.Name = "ExportPaymentDestination" Then
		ShowMessageBox(Undefined,Items.Exporting.CurrentData.PaymentDestination);
	Else
		OpenForm("Document.PaymentOrder.ObjectForm",
			New Structure("Key", Items.Exporting.CurrentData.Document),
			Items.Exporting.CurrentData.Document
		);
	EndIf;
	
EndProcedure // ExportSelection()

// Procedure - command handler Setting.
//
&AtClient
Procedure Setting(Command)
	
	OpenForm("DataProcessor.ClientBank.Form.FormSetting",
		New Structure(
			"Script, ExternalDataProcessor, FormatVersion, UUID",
			Object.Encoding, Object.ExternalDataProcessor, Object.FormatVersion, UUID
		)
	);
	
EndProcedure // Setting()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingsChange" + UUID Then
		Object.Encoding = Parameter.Encoding;
		Object.ExternalDataProcessor = Parameter.ExternalDataProcessor;
		Object.FormatVersion = Parameter.FormatVersion;
	ElsIf EventName = "RefreshStateED" Then
		FillDump();
	EndIf;
	

EndProcedure // NotificationProcessing()

// Filling the amount of marked items.
//
&AtClient
Procedure FillAmount76AtClient(CurRow)
	
	CurRow.DocumentAmountAllocated = ?(CurRow.Exporting, CurRow.DocumentAmount, 0);
	
EndProcedure

// Filling the amount of marked items.
//
&AtServer
Procedure FillAmountsAllocatedAtServer(CurRow)
	
	CurRow.DocumentAmountAllocated = ?(CurRow.Exporting, CurRow.DocumentAmount, 0);
	
EndProcedure

// Procedure - OnChange event handler of the Export field from Export list .
//
&AtClient
Procedure DowloadingExportOnChange(Item)
	
	CurRow = Items.Exporting.CurrentData;
	FillAmount76AtClient(CurRow)
	
EndProcedure // DowloadingExportOnChange()

//( elmi #17 (112-00003) 
&AtServer
Function UpLoadTSExporting ()
	
VT = Object.Exporting.Unload();

Return  TransformValueTableIntoArrayOfStructure(VT);

EndFunction	
//) elmi

//( elmi #17 (112-00003) 
&AtServer
Function TransformValueTableIntoArrayOfStructure(vtData) Export
    
    arData = New Array;
	

    For Each StringVT IN vtData Do
    
        StrucStringVT = New Structure;
		
		For Each ColumnName Из vtData.Columns Do
            StrucStringVT.Insert(ColumnName.Name, StringVT[ColumnName.Name]);
        EndDo;
        
        arData.Add(StrucStringVT);
        
    EndDo;
    
    Возврат arData;
    
EndFunction
//) elmi

//elmi #17 (112-00003)	
&AtServer
Procedure RunCommandOnServer(ParametersDataProcessors) Export
	
AdditionalReportsAndDataProcessors.RunCommand( ParametersDataProcessors );
	
EndProcedure	
