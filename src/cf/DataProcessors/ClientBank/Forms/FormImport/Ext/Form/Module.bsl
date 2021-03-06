﻿////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Function checks the correctness of the form attribute filling.
//
&AtClient
Function CheckFillOfFormAttributes()
	
	CheckResultOk = True;
	
	// Attributes filling check.
	If Not ValueIsFilled(Object.Encoding) Then
		MessageText = NStr("en='Encoding is not specified in the settings.';ru='В настройках не указана кодировка!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "Encoding", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.FormatVersion) Then
		MessageText = NStr("en='Exchange format version is not specified in the settings.';ru='В настройках не указана версия формата обмена!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "FormatVersion", CheckResultOk);
	EndIf;
	
	Return CheckResultOk;
	
EndFunction // CheckFillFormAttributes()

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

// Procedure imports data from a file.
//
&AtServer
Procedure DataLoadFromFile()
	
	FormAttributeToValue("Object").Import(ImportTitle);
	
EndProcedure // DataLoadFromFile()

// Procedure sets flags.
//
&AtClient
Procedure SetFlags(Table, Field, ValueOfFlag, FillAmounts)
	
	For Each String IN Table Do
		String[Field] = ValueOfFlag;
		If FillAmounts Then
			FillAmount76AtClient(String)
		EndIf;
	EndDo;
	
EndProcedure // SetFlags()

// Function receives a date from string.
//
&AtServer
Function GetDateFromString(Receiver, Source)
	
	Buffer = Source;
	DotPosition = Find(Buffer, ".");
	If DotPosition = 0 Then
		Return NStr("en='Incorrect format of the date row';ru='Неверный формат строки с датой'");
	EndIf;
	NumberDate = Left(Buffer, DotPosition - 1);
	Buffer = Mid(Buffer, DotPosition + 1);
	DotPosition = Find(Buffer, ".");
	If DotPosition = 0 Then
		Return NStr("en='Incorrect format of the date row';ru='Неверный формат строки с датой'");
	EndIf;
	DateMonth = Left(Buffer, DotPosition - 1);
	DateYear = Mid(Buffer, DotPosition + 1);
	If StrLen(DateYear) = 2 Then
		If Number(DateYear) < 50 Then
			DateYear = "20" + DateYear;
		Else
			DateYear = "19" + DateYear ;
		EndIf;
	EndIf;
	Try
		Receiver = Date(Number(DateYear), Number(DateMonth), Number(NumberDate));
	Except
		Return NStr("en='Failed to convert a string into date';ru='Не удалось преобразовать строку в дату'");
	EndTry;
	
	Return Receiver;
	
EndFunction // GetDateFromString()

// Function defines whether the company is a payer.
//
&AtServer
Function CompanyPayer(DocumentKind)
	
	If DocumentKind = "PaymentReceipt" Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction // CompanyPayer()

// Function finds the counterparty contract.
//
&AtServer
Function FindContract(OwnerTreaty, CompanyContracts = Undefined, ContractKindsList = Undefined)
	
	NewContract = Catalogs.CounterpartyContracts.EmptyRef();
	Query = New Query;
	QueryText = 
	"SELECT ALLOWED TOP 2
	|	CounterpartyContracts.Ref,
	|	CASE
	|		WHEN CatalogOwner.Ref IS Not NULL 
	|			THEN 1
	|		ELSE 2
	|	END AS Priority
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|		LEFT JOIN Catalog.Counterparties AS CatalogOwner
	|		ON CounterpartyContracts.Owner = CatalogOwner.Ref
	|			AND CounterpartyContracts.Ref = CatalogOwner.ContractByDefault
	|WHERE
	|	&TextFilter
	|
	|ORDER BY
	|	Priority";
	
	//( elmi #17 (112-00003)
	//Query.SetParameter("OwnerTreaty", OwnerTreaty);
	//Query.SetParameter("CompanyContracts", CompanyContracts);
	//Query.SetParameter("ContractKindsList", ContractKindsList);
	Query.SetParameter("ContractOwner", OwnerTreaty);
	Query.SetParameter("CompanyContract", CompanyContracts);
	Query.SetParameter("ContractTypeList", ContractKindsList);
	//) elmi
	
	TextFilter =
	
	//( elmi #17 (112-00003)
	//"	CounterpartyContract.Owner = &ContractOwner"
	"	CounterpartyContracts.Owner = &ContractOwner"
	//) elmi
	
	+ ?(CompanyContracts <> Undefined, "
	|	And CounterpartyContracts.Company = &CompanyContract", "") 
  +	"	And CounterpartyContracts.DeletionMark = FALSE"
  + ?(ContractKindsList <> Undefined, "
	|	And CounterpartyContracts.ContractType IN (&ContractTypeList)", "");
	
	QueryText = StrReplace(QueryText, "&TextFilter", TextFilter);
	Query.Text = QueryText;
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Ref;
	Else
		Return NStr("en='Not found';ru='Не найден'");
	EndIf;
	
EndFunction // FindContract()

// Function forms a match of imported items.
//
&AtServer
Function GenerateMapOfItemsBeingImported()
	
	ImportExportable = CreateMapFromString(
		Upper("Number,Date,Amount,PaymentKind,PayKind,StatementDate,StatementTime,StatementContent,DateCredited,Date_Received,"
		   + "PayerAccount,Payer,PayerTIN,Payer1,PayerBankAcc,PayerBank1,PayerBank2,PayerBIC,PayerBalancedAccount,Payer2,Payer3,Payer4,"
		   + "PayeeAccount,Recipient,PayeeTIN,Payee1,PayeeBankAcc,PayeeBank1,PayeeBank2,PayeeBIC,PayeeBalancedAccount,Payee2,Payee3,Payee4,"
		   + "AuthorStatus,PayerRegistrationNumber,PayeeRegistrationNumber,KBKIndicator,BasisIndicator,PeriodIndicator,NumberIndicator,DateIndicator,TypeIndicator,"
		   + "PaymentDestination,PaymentDestination1,PaymentDestination2,PaymentDestination3,PaymentDestination4,PaymentDestination5,PaymentDestination6,"
		   + "OrderOfPriority,PaymentDueDate,PaymentCondition1,PaymentCondition2,PaymentCondition3,AcceptanceTerm,LetterOfCreditType,PaymentByRepr,AdditionalConditions,NumberVendorAccount,DocSendingDate,Code"
		)
	);
	
	Return ImportExportable;
	
EndFunction // GenerateImportedItemsMatch()

// Procedure forms a match of not empty items when importing.
//
&AtServer
Procedure GenerateMapsOFNotEmptyItemsOnImport(ImportIsNotEmpty, ImportBlankPaymentOrder, ImportBlankPaymentOrderBudget)
	
	ImportBlankPaymentOrder = CreateMapFromString(
		"Number,Date,Amount,PayerAccount,PayerTIN,PayeeAccount,PayeeTIN"
	);
	
	// According to issuer status it is defined that the payment is - tax.
	ImportBlankPaymentOrderBudget = CreateMapFromString(
		"Number,Date,Amount,PayerAccount,PayerTIN,PayeeAccount,PayeeTIN,"
	  + "AuthorStatus,PayerRegistrationNumber,PayeeRegistrationNumber,KBKIndicator,BasisIndicator,"
	  + "PeriodIndicator,NumberIndicator,DateIndicator,TypeIndicator"
	);
	
	ImportIsNotEmpty = New Array;
	ImportIsNotEmpty.Add(ImportBlankPaymentOrder);
	ImportIsNotEmpty.Add(ImportBlankPaymentOrderBudget);
	
EndProcedure // GenerateNotEmptyItemsMatchOnImport()

// Function receives an import string.
//
&AtServer
Function GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing)
	
	Buffer = "";
	While IsBlankString(Buffer)
	 OR Left(Buffer, 2) = "//" Do
		If ImportCurrentRow > ImportLineCount Then
			Return "";
		EndIf;
		Buffer = TrimAll(StrGetLine(ImportTextForParsing, ImportCurrentRow));
		ImportCurrentRow = ImportCurrentRow + 1;
	EndDo;
	
	Return Buffer;
	
EndFunction // GetImportString()

// Function parses tag string.
//
&AtServer
Function ParseTagString(ParsingString, Tag, Value)
	
	AssignmentPosition = Find(ParsingString, "=");
	If AssignmentPosition = 0 Then
		Return False;
	EndIf;
	
	Tag = Upper(TrimAll(Left(ParsingString, AssignmentPosition - 1)));
	Value = TrimAll(Mid(ParsingString, AssignmentPosition + 1));
	
	Return Not IsBlankString(Tag);
	
EndFunction // ParseTagString()

// Function loads the document section
//
&AtServer
Function ImportDocumentSection(DocumentRow, ImportCurrentRow, ImportLineCount, ImportTextForParsing, ImportExportable)
	
	ParsingString = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
	While Left(Upper(TrimAll(ParsingString)), 14) <> "EndDocument" Do
		Value = "";
		Tag = "";
		If ParseTagString(ParsingString, Tag, Value) Then
			If ImportExportable[Tag] = True Then
				DocumentRow[Tag] = Value;
			Else
				
				// Invalid title attribute.
				MessageText = NStr("en='Invalid attribute of payment document, the %Import% line: %ParsingString%';
									|ru='Неверный реквизит платежного документа, строка %Import%: %ParsingString%'");
				MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
				MessageText = StrReplace(MessageText, "%ParsingString%", ParsingString);
				SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
				Return False;
				
			EndIf;
		Else
			
			// Invalid title attribute.
			MessageText = NStr("en='Payment document structure is broken, the %Import% string: %ParsingString%';
								|ru='Нарушена структура платежного документа, строка %Import%: %ParsingString%'");
			MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
			MessageText = StrReplace(MessageText, "%ParsingString%", ParsingString);
			SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
			Return False;
			
		EndIf;
		ParsingString = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
	EndDo;
	
	Return True;
	
EndFunction // ImportDocumentSection()

// Function loads the settlement account sections.
//
&AtServer
Function ImportBankAccSection(SAAccountRow, ImportCurrentRow, ImportLineCount, ImportTextForParsing, SettlementsAccountsTags)
	
	ParsingString = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
	Value = "";
	Tag = "";
	While ParseTagString(ParsingString, Tag, Value) Do
		If SettlementsAccountsTags[Tag] = True Then
			SAAccountRow[Tag] = Value;
		Else
			// Invalid title attribute.
			MessageText = NStr("en='Invalid attribute in the account description section, the %Import% line: %ParsingString%';
								|ru='Неверный реквизит в секции описания расчетного счета, строка %Import%: %ParsingString%'");
			MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
			MessageText = StrReplace(MessageText, "%ParsingString%", ParsingString);
			SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
			Return False;
		EndIf;
		ParsingString = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
		Value = "";
		Tag = "";
	EndDo;
	
	If UPPER(Left(TrimAll(ParsingString), 13)) = "ENDBANKACC" Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction // ImportBankAccSection()

// Procedure checks for an empty value while importing.
//
&AtServer
Procedure CheckForBlankImportValue(ImportRow, PropertyName, PresentationProperties, ImportIsNotEmpty)
	
	If ImportIsNotEmpty[0][PropertyName] = True Then
		If Not ValueIsFilled(ImportRow[PropertyName]) Then
			RowRemark = NStr("en='""%PropertyName%"" is not filled!';ru='Не заполнено ""%PropertyName%""!'");
			RowRemark = StrReplace(RowRemark, "%PropertyName%", PropertyName);
			AddComment(ImportRow, 3, RowRemark);
		EndIf;
	EndIf;
	
EndProcedure // CheckForEmptyImportValue()

// Function imports the exchange file title.
//
&AtServer
Function ImportHeaderString(HeaderRowText, TagsHeader, ImportTitle, ImportCurrentRow)
	
	Value = "";
	Tag = "";
	ParseTagString(HeaderRowText, Tag, Value);
	If TagsHeader[Tag] = True Then
		ImportTitle[Tag] = Value;
	Else
		
		// Invalid title attribute.
		MessageText = NStr("en='Invalid title attribute, the %Import% line: %TitleStringText%';
							|ru='Неверный реквизит заголовка, строка %Import%: %TitleStringText%'");
		MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
		MessageText = StrReplace(MessageText, "%TitleStringText%", HeaderRowText);
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
		
	EndIf;
	
EndFunction // ImportHeaderString()

// Function checks if a row has digits only.
//
// CheckString
//  Parameters - String for digit checking only
//
// Returns:
//   Boolean
//
&AtServer
Function AreNotDigits(Val CheckString)
	
	If TypeOf(CheckString) <> Type("String") Then
		Return True;
	EndIf;
	CheckString = TrimAll(CheckString);
	Length = StrLen(CheckString);
	For Ct = 1 To Length Do
		If Find("0123456789", Mid(CheckString, Ct, 1)) = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction // AreNotDigits()

// Procedure recognizes data in document row.
//
&AtServer
Procedure RecognizeDataInDocumentRow(DocumentRow)
	
	BlankDate = Date("00010101");
	
	// 1) We define the payment type — incoming or outgoing.
	PaymentOrder = Upper(StrReplace(TrimAll(DocumentRow.Operation), " ", "")) = "PaymentOrder";
	Outgoing = (DocumentRow.PayerAccount = Object.BankAccount.AccountNo);
	
	// 2) We define the document type in application.
	DocumentKind = ?(Outgoing, "PaymentExpense", "PaymentReceipt");
	DocumentName = ?(Outgoing, "Payment expense", "Payment receipt");
	
	DocumentRow.DocumentName = DocumentName;
	DocumentRow.DocumentKind = DocumentKind;
	AttributeAccounts = ?(Outgoing, "BankAccount", "CounterpartyAccount");
	
	// 3) We find previously imported (typed) document.
	// Attributes for search: Document Type, Date, Number, Account #
	
	// We recognize document date.
	DocDate = BlankDate;
	
	
	//( elmi #17 (112-00003)
	If  ValueIsFilled(DocumentRow.DocDate) И TypeOf(DocumentRow.DocDate) = Type("Date") Then
		Result   =  DocumentRow.DocDate;
		DocDate  =  DocumentRow.DocDate;
	Else	 
	//) elmi	
		
		If Not IsBlankString(DocumentRow.DateCredited) Then
			Result = GetDateFromString(DocDate, DocumentRow.DateCredited);
		ElsIf Not IsBlankString(DocumentRow.Date_Received) Then
			Result = GetDateFromString(DocDate, DocumentRow.Date_Received);
		Else
			Result = GetDateFromString(DocDate, DocumentRow.Date);
		EndIf;
		
	//( elmi #17 (112-00003)	
	EndIf;
    //) elmi	
	
	
	If ValueIsFilled(Result) Then
		DocumentRow.DocDate = Result;
		NumberForDocSearch = DocumentRow.Number;
		AttributeOfDate = "IncomingDocumentDate";
		NumberAttribute = "IncomingDocumentNumber";
		AllAttributesSearchIs = True;
	EndIf;
	
	DocumentRow.DocNo = DocumentRow.Number;
	
	If AllAttributesSearchIs Then
		
		// If there are several items, the first
		// with matching account number is preferred.
		QuerySearchDocument = New Query;
		QuerySearchDocument.Text = 
		"SELECT ALLOWED
		|	PaymentDocuments.Ref,
		|	PaymentDocuments.Posted,
		|	PaymentDocuments." + NumberAttribute + " AS
		|	Number, PaymentDocuments." + AttributeOfDate + " AS Date,
		|	PaymentDocuments.CounterpartyAccount.AccountNo AS AccountNo,
		|	PaymentDocuments.Company
		|FROM
		|	Document." + DocumentRow.DocumentKind + " AS
		|PaymentDocuments
		|	WHERE BEGINOFPERIOD(PaymentDocuments." + AttributeOfDate + ", DAY)=
		|	&DateDoc And PaymentDocuments.BankAccount
		|	= &BankAccount And PaymentDocuments.Company = &Company";
		

		QuerySearchDocument.SetParameter("DateDoc", DocDate);
		QuerySearchDocument.SetParameter("Company", Object.Company);
		QuerySearchDocument.SetParameter("BankAccount", Object.BankAccount);
		Result = QuerySearchDocument.Execute().Select();
		AccountForDocSearch = ?(Outgoing, DocumentRow.PayeeAccount, DocumentRow.PayerAccount);
		NumberLength = StrLen(NumberForDocSearch);
		QuantityDoc = 0;
		
		While Result.Next() Do
			SelectionNumber = Right(TrimAll(Result.Number), NumberLength);
			If SelectionNumber = NumberForDocSearch
			  AND (NOT ValueIsFilled(Result.AccountNo) OR Result.AccountNo = AccountForDocSearch) Then
				If QuantityDoc = 0 Then
					DocumentRow.Document = Result.Ref;
					DocumentRow.Posted = Result.Posted;
					DocumentRow.DocNo = Result.Number;
					DocumentRow.DocDate = Result.Date;
				EndIf;
				QuantityDoc = QuantityDoc + 1;
			EndIf;
		EndDo;
		
		If QuantityDoc > 1 Then
			RowRemark = NStr("en='Several (%QuantityDoc%) corresponding documents have been found in the infobase!';
							|ru='В информационной базе найдено несколько(%QuantityDoc%) соответствующих документов!'");
			RowRemark = StrReplace(RowRemark, "%QuantityDoc%", QuantityDoc);
			AddComment(DocumentRow, 1, RowRemark);
		EndIf;
		
		// If the document already is in the IB then we take all data from it.
		DocumentIsFound = ValueIsFilled(DocumentRow.Document);
		If DocumentIsFound Then
			Document = DocumentRow.Document; 
			DocumentRow.OperationKind = Document.OperationKind; 
			DocumentRow.CFItem = Document.Item; 
			DocumentRow.BankAccount = Object.BankAccount;
			DocumentRow.CounterpartyAccount = Document.CounterpartyAccount;
			DocumentRow.Counterparty = Document.Counterparty;
			If Document.PaymentDetails.Count() <> 0 Then
				DocumentRow.Contract = Document.PaymentDetails[0].Contract;
				DocumentRow.AdvanceFlag = Document.PaymentDetails[0].AdvanceFlag;
				DocumentRow.Order = Document.PaymentDetails[0].Order;
			EndIf;
		EndIf;
		
	EndIf;
	
	// 4) We define the document operation type.
	If Not ValueIsFilled(DocumentRow.OperationKind) Then
		If Outgoing Then
			If ValueIsFilled(DocumentRow.AuthorStatus) Then // tax payment 
				If DocumentRow.AuthorStatus = "06" OR DocumentRow.AuthorStatus = "08" 
				 OR ((Number(DocumentRow.AuthorStatus) >= 16) AND (Number(DocumentRow.AuthorStatus) <= 20)) Then
					OperationKindDocument = Enums.OperationKindsPaymentExpense.Other;
				Else
					OperationKindDocument = Enums.OperationKindsPaymentExpense.Taxes;
				EndIf;
			ElsIf Catalogs.BankAccounts.FindByAttribute("AccountNo", DocumentRow.PayeeAccount).Owner = Object.BankAccount.Owner Then // transfer to other account
				OperationKindDocument = Enums.OperationKindsPaymentExpense.Other;
			Else // Payment to vendor
				OperationKindDocument = Enums.OperationKindsPaymentExpense.Vendor;
			EndIf; 
		Else
			OperationKindDocument = Enums.OperationKindsPaymentReceipt.FromCustomer;
		EndIf;
		DocumentRow.OperationKind = OperationKindDocument;
	Else
		OperationKindDocument = DocumentRow.OperationKind;
	EndIf;
	
	// 5) We define the company bank account
	If Not ValueIsFilled(DocumentRow.BankAccount) Then
		DocumentRow.BankAccount = Object.BankAccount;
	EndIf;
	
	// 6) We define the counterparty bank account    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	If Not ValueIsFilled(DocumentRow.CounterpartyAccount) Then
		AccountSearchQuery = New Query;
		If CompanyPayer(DocumentKind) Then
			CounterpartyAccount = DocumentRow.PayeeAccount;
			CounterpartyTIN = DocumentRow.PayeeTIN;
			CounterpartyRegistrationNumber = DocumentRow.PayeeRegistrationNumber;
			If ValueIsFilled(DocumentRow.Payee1) Then
				CounterpartyName = DocumentRow.Payee1;
			Else
				CounterpartyName = DocumentRow.Payee;
			EndIf;
			AccountSearchQuery.SetParameter("AccountNo", DocumentRow.PayeeAccount);
		Else
			AccountSearchQuery.SetParameter("AccountNo", DocumentRow.PayerAccount);
			CounterpartyAccount = DocumentRow.PayerAccount;
			CounterpartyTIN = DocumentRow.PayerTIN;
			CounterpartyRegistrationNumber = DocumentRow.PayerRegistrationNumber;
			If DocumentRow.Payer1 <> "" Then
				CounterpartyName = DocumentRow.Payer1;
			Else
				CounterpartyName = DocumentRow.Payer;
			EndIf;
		EndIf;
		AccountSearchQuery.SetParameter("CounterpartyTIN", CounterpartyTIN);
		AccountSearchQuery.Text = 
		"SELECT ALLOWED
		|	BankAccounts.Owner,
		|	BankAccounts.Ref,
		|	BankAccounts.AccountNo
		|FROM
		|	Catalog.BankAccounts AS BankAccounts
		|WHERE
		|	BankAccounts.Owner REFS Catalog.Counterparties 
		|	" + ?(NOT IsBlankString(CounterpartyTIN), "AND BankAccounts.Owner.TIN = &CounterpartyTIN", "") + "
		|	And BankAccounts.AccountNo = &AccountNo";
		
		SearchSelection = AccountSearchQuery.Execute().Select();
		Counterparty = Catalogs.Counterparties.EmptyRef();
		
		If SearchSelection.Next() Then
			DocumentRow.CounterpartyAccount = SearchSelection.Ref;
			Counterparty = SearchSelection.Owner;
		Else
			RowRemark = NStr("en='Counterparty account is not found (%CounterpartyAccount%).';ru='Не найден счет контрагента (%CounterpartyAccount%).'");
			RowRemark = StrReplace(RowRemark, "%CounterpartyAccount%", CounterpartyAccount);
			AddComment(DocumentRow, 2, RowRemark);
			
			StringGLCounterpartyAccount = NStr("en='Not found (%AccountOfCompany%).';ru='Не найден (%AccountOfCompany%).'");
			StringGLCounterpartyAccount = StrReplace(RowRemark, "%CounterpartyAccount%", CounterpartyAccount);
			DocumentRow.CounterpartyAccount = StringGLCounterpartyAccount;
		EndIf;
		
		If SearchSelection.Count() > 1 Then
			RowRemark = NStr("en='The several (%Quantity%) same banking accounts have been found in the infobase!';
							|ru='В информационной базе найдено несколько(%Quantity%) одинаковых банковских счетов!'");
			RowRemark = StrReplace(RowRemark, "%Quantity%", SearchSelection.Count());
			AddComment(DocumentRow, 1, RowRemark);
		EndIf;
	EndIf;
	
	
	// 7) We define counterparty.
	If Not ValueIsFilled(DocumentRow.Counterparty) Then
		If ValueIsFilled(Counterparty) Then
			DocumentRow.Counterparty = Counterparty;
		ElsIf Not IsBlankString(CounterpartyTIN) or Not IsBlankString(CounterpartyRegistrationNumber) or Not IsBlankString(CounterpartyName) Then
			
			DocumentRow.Counterparty = Counterparty;
			QuerySearchCounterparty = New Query(
			"SELECT ALLOWED
			|	Counterparties.Ref,
			|	Counterparties.TIN,
			|	Counterparties.RegistrationNumber,
			|	Counterparties.Description
			|FROM
			|	Catalog.Counterparties AS Counterparties
			|WHERE
			|	Counterparties.TIN = &CounterpartyTIN or Counterparties.RegistrationNumber = &CounterpartyRegistrationNumber or Counterparties.Description = &CounterpartyName");
			
			QuerySearchCounterparty.SetParameter("CounterpartyTIN", CounterpartyTIN);
			QuerySearchCounterparty.SetParameter("CounterpartyRegistrationNumber", CounterpartyRegistrationNumber);
			QuerySearchCounterparty.SetParameter("CounterpartyName", CounterpartyName);
			SearchSelection = QuerySearchCounterparty.Execute().Unload();
			
			// We find counterparty by TIN .
			FilterParameters = New Structure;
			If Not IsBlankString(CounterpartyTIN) Then
				FilterParameters.Insert("TIN", CounterpartyTIN);
			EndIf;
			FoundsCounterparties = SearchSelection.FindRows(FilterParameters);
			
			// If we did not find by TIN then we try to find by RegistrationNumber.
			If FoundsCounterparties.Count() = 0
			AND Not IsBlankString(CounterpartyRegistrationNumber) Then
				FilterParameters = New Structure;
				FilterParameters.Insert("Description", CounterpartyName);
				FoundsCounterparties = SearchSelection.FindRows(FilterParameters);
			EndIf;
			
			// If we did not find by RegistrationNumber then we try to find by Description.
			If FoundsCounterparties.Count() = 0
			AND Not IsBlankString(CounterpartyName) Then
				FilterParameters = New Structure;
				FilterParameters.Insert("RegistrationNumber", CounterpartyRegistrationNumber);
				FoundsCounterparties = SearchSelection.FindRows(FilterParameters);
			EndIf;
			
			If FoundsCounterparties.Count() > 0 Then
				DocumentRow.Counterparty = FoundsCounterparties[0].Ref;
			EndIf;
			
			If FoundsCounterparties.Count() > 1 Then
				RowRemark = NStr("en='Several (%Quantity%) same TIN counterparties have been found in the infobase!';
								|ru='В информационной базе найдено несколько(%Quantity%) контрагентов с одинаковым ИНН!'");
				RowRemark = StrReplace(RowRemark, "%Quantity%", FoundsCounterparties.Count());
				AddComment(DocumentRow, 2, RowRemark);
			ElsIf FoundsCounterparties.Count() = 0 Then
				RowRemark = NStr("en='Counterparty is not found (%CounterpartyName%,TIN %TINCounterparty%).';
								|ru='Не найден контрагент (%CounterpartyName%, ИНН %TINCounterparty%).'");
				RowRemark = StrReplace(RowRemark, "%CounterpartyName%", CounterpartyName);
				RowRemark = StrReplace(RowRemark, "%TINCounterparty%", CounterpartyTIN);
				AddComment(DocumentRow, 2, RowRemark);
				StringCounterparty = NStr("en='Not found (%CounterpartyName%, TIN, %TINCounterparty%).';
										|ru='Не найден (%CounterpartyName%, ИНН %TINCounterparty%).'");
				StringCounterparty = StrReplace(StringCounterparty, "%CounterpartyName%", CounterpartyName);
				StringCounterparty = StrReplace(StringCounterparty, "%TINCounterparty%", CounterpartyTIN);
				DocumentRow.Counterparty = StringGLCounterpartyAccount;
			EndIf;
			
		Else
			AddComment(DocumentRow, 2, NStr("en='The TIN,Reg.No or Name of the counterparty is not specified. ';
											|ru='Не указан ни ИНН, ни Рег.Номер, ни имя контрагента. '"));
			StringCounterparty = NStr("en='Not found (%CounterpartyName%, TIN, Reg.No or Name is not specified).';
										|ru='Не найден (%CounterpartyName%, не указан ИННРег.Номер, Имя).'");
			StringCounterparty = StrReplace(StringCounterparty, "%CounterpartyName%", CounterpartyName);
			DocumentRow.Counterparty = StringCounterparty;
		EndIf;
	EndIf;
	
	// 8) We define the counterparty contract
	If DocumentRow.OperationKind <> Enums.OperationKindsPaymentExpense.Taxes
	AND Not ValueIsFilled(DocumentRow.Contract) Then
		DocumentRow.Contract = FindContract(DocumentRow.Counterparty, Object.Company);
		If DocumentRow.Contract = NStr("en='Not found';ru='Не найден'") Then
			DocumentRow.Contract = FindContract(DocumentRow.Counterparty);
		EndIf;
		If DocumentRow.Contract = NStr("en='Not found';ru='Не найден'") Then
			AddComment(DocumentRow, 2, NStr("en='The counterparty contract is not found. ';ru='Не найден договор контрагента. '"));
		EndIf;
	EndIf;
	
	// 9) We define the CF item by default.
	If Not ValueIsFilled(DocumentRow.CFItem) Then
		If Outgoing Then
			DocumentRow.CFItem = Object.CFItemOutgoing;
		Else
			DocumentRow.CFItem = Object.CFItemIncoming;
		EndIf;
	EndIf;
	
	// 10) We define amount.
	
	// Convert from string into number.
	Buffer = TrimAll(StrReplace(DocumentRow.Amount, " ", ""));
	
	If Not AreNotDigits(StrReplace(StrReplace(StrReplace(Buffer, ".", ""), "-", ""), ",", "")) Then
		Amount = Number(Buffer);
		If Amount < 0 Then
			Amount = - Amount;
		EndIf;
		DocumentRow.DocumentAmount = Amount;
		If Outgoing Then
			DocumentRow.AmountCredited = Amount;
		Else
			DocumentRow.AmountDebited = Amount;
		EndIf;
	Else
		RowRemark = NStr("en='Incorrect document amount (%Buffer%) is specified!';ru='Указана неверная сумма документа(%Buffer%)!'");
		RowRemark = StrReplace(RowRemark, "%Buffer%", Buffer);
		AddComment(DocumentRow, 4, RowRemark);
	EndIf;
	
	// 11) We define the payment priority.
	
	// Convert from string into number
	Buffer = TrimAll(DocumentRow.OrderOfPriority);
	If Buffer <> "" AND Not AreNotDigits(Buffer) Then
		DocumentRow.PaymentPriority = Number(Buffer);
	Else
		DocumentRow.PaymentPriority = 0;
	EndIf;
	
	// 12) We define DocDateIndicator (for Payment order
	// outgoing when paying taxes).
	
	// We convert to date from a string if it is not empty
	If Not IsBlankString(DocumentRow.DateIndicator) Then
		Result = GetDateFromString(DocumentRow.DocDateIndicator, DocumentRow.DateIndicator);
		If Not ValueIsFilled(Result) Then
			DocumentRow.DocDateIndicator = Undefined;
		EndIf;
	EndIf;
	
	// 13) DateCredited and DateRecieved, DatePosted.
	
	// We convert to date from a string if it is not empty
	If Not IsBlankString(DocumentRow.DateCredited) Then
		Result = GetDateFromString(DocumentRow.WrittenOff, DocumentRow.DateCredited);
		If Not ValueIsFilled(Result) Then
			DocumentRow.WrittenOff = BlankDate;
		Else
			DocumentRow.DatePosted = DocumentRow.WrittenOff;
		EndIf;
	Else
		DocumentRow.WrittenOff = BlankDate;
	EndIf;
	
	// We convert to date from a string if it is not empty.
	If Not IsBlankString(DocumentRow.Date_Received) Then
		Result = GetDateFromString(DocumentRow.Debited, DocumentRow.Date_Received);
		If Not ValueIsFilled(Result) Then
			DocumentRow.Debited = BlankDate;
		Else
			DocumentRow.DatePosted = DocumentRow.Debited;
		EndIf;
	Else
		DocumentRow.Debited = BlankDate;
	EndIf;
	
	// If PaymentDestination is empty then we form it from PaymentDestination1...PaymentDestination6.
	If IsBlankString(DocumentRow.PaymentDestination) Then
		DocumentRow.PaymentDestination = DocumentRow.PaymentDestination1;
		For Ct = 2 To 6 Do
			If Not ValueIsFilled(DocumentRow["PaymentDestination" + Ct]) Then
				Break;
			EndIf;
			DocumentRow.PaymentDestination = DocumentRow.PaymentDestination + Chars.LF + DocumentRow["PaymentDestination" + Ct];
		EndDo;
	EndIf;
	
EndProcedure // RecognizeDataInDocumentRow()

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

// Function adds and returns the new attribute description.
//
&AtServer
Function AddNewAttributeDescription(Presentation, Attribute, CounterpartyType, NewCounterparty, DocumentRow)
	
	AttributesOfNewCounterparty = NewCounterparty.Add();
	
	AttributesOfNewCounterparty.Presentation = Presentation;
	AttributesOfNewCounterparty.Value      = DocumentRow[CounterpartyType + Attribute];
	AttributesOfNewCounterparty.Attribute      = CounterpartyType + Attribute;
	
	Return AttributesOfNewCounterparty;
	
EndFunction // AddNewAttributeDescription()

// Procedure creates a list of not found counterparties.
//
&AtServer
Procedure ListOfNotFound(DocumentRow, BankAccount, CounterpartyTable)
	
	IsFoundCounterparty = TypeOf(DocumentRow.Counterparty) <> Type("String");
	IsFoundAccount       = TypeOf(DocumentRow.CounterpartyAccount) <> Type("String");
	
	CounterpartyType = ?(DocumentRow.PayerAccount = BankAccount.AccountNo, "Payee", "Payer");
	
	If ValueIsFilled(DocumentRow[CounterpartyType + "TIN"]) Then
		FoundRecordAboutCounterparty = FindTreeItem(CounterpartyTable.GetItems(), "Value", DocumentRow[CounterpartyType + "TIN"]);
	Else
		End = ?(DocumentRow[CounterpartyType + "1"] = "", "", "1");
		FoundRecordAboutCounterparty = FindTreeItem(CounterpartyTable.GetItems(), "Value", DocumentRow[CounterpartyType + End]);
	EndIf;
	
	// Counterparty
	If FoundRecordAboutCounterparty = Undefined Then
		
		NewCounterparty = CounterpartyTable.GetItems().Add();
		
		End = ?(DocumentRow[CounterpartyType + "1"] = "", "", "1");
		
		NewCounterparty.Presentation = DocumentRow[CounterpartyType + End];
		NewCounterparty.RowNum     = DocumentRow.LineNumber;
		NewCounterparty.Import     = True;
		NewCounterparty.IsCounterparty = True;
		
		AddNewAttributeDescription("Description", End, CounterpartyType, NewCounterparty.GetItems(), DocumentRow);
		AddNewAttributeDescription("TIN"		  , "TIN"	 , CounterpartyType, NewCounterparty.GetItems(), DocumentRow);
		AddNewAttributeDescription("RegistrationNumber", "RegistrationNumber", CounterpartyType, NewCounterparty.GetItems(), DocumentRow);
		
		If IsFoundCounterparty Then
			NewCounterparty.Attribute = DocumentRow.Counterparty;
		EndIf;
		
	Else
		
		NewCounterparty = FoundRecordAboutCounterparty.GetParent();
		
		If NewCounterparty = Undefined Then
			NewCounterparty = FoundRecordAboutCounterparty;
		EndIf;
		
	EndIf;
	
	FoundStrings = FindTreeItem(NewCounterparty.GetItems(), "Value", DocumentRow[CounterpartyType + "account"]);
	
	If Not IsFoundAccount AND FoundStrings = Undefined Then
		
		AttributesOfNewCounterparty = AddNewAttributeDescription("R/account", "account", CounterpartyType, NewCounterparty.GetItems(), DocumentRow);
		
		DirectSettlements = IsBlankString(DocumentRow[CounterpartyType + "2"]);
		
		If DirectSettlements Then
			
			AddNewAttributeDescription("Bank",            "BANK1",   CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("City of bank",    "BANK2",   CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			//( elmi #17 (112-00003) 
			//AddNewAttributeDescription("Bank code",     "BIN",     CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Bank code",       "BIC",     CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			//) elmi
			AddNewAttributeDescription("Corr. bank account", "BALANCEDACCOUNT", CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			
		Else
			
			AddNewAttributeDescription("Bank",                     "3",        CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("City of bank",              "4",        CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Corr. bank account",          "BANKACC", CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Bank's processing center",                 "BANK1",    CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Location of bank processing center", "BANK2",    CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Code of bank processing center",             "BIN",      CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			AddNewAttributeDescription("Corr. account of bank processing center",       "BALANCEDACCOUNT",  CounterpartyType, AttributesOfNewCounterparty.GetItems(), DocumentRow);
			
		EndIf;
		
	EndIf;
	
EndProcedure // NotFoundList()

// Procedure fills the documents to be imported.
//
&AtServer
Function FillDocumentsForImport(ImportTextForParsing)
	
	CounterpartyTable.GetItems().Clear();
	
	// We prepare the data processing structures.
	DocumentsForImport = Object.Import.Unload();
	
	ImportExportable = GenerateMapOfItemsBeingImported();
	
	ImportIsNotEmpty = Undefined;
	ImportBlankPaymentOrder = Undefined;
	ImportBlankPaymentOrderBudget = Undefined;
	
	BankAccountsToImport = Object.ImportBankAccounts.Unload();
	
	GenerateMapsOFNotEmptyItemsOnImport(
		ImportIsNotEmpty,
		ImportBlankPaymentOrder,
		ImportBlankPaymentOrderBudget
	);
	SettlementsAccountsTags = CreateMapFromString(
		Upper("StartDate,EndDate,BankAcc,OpeningBalance,DebitedTotal,CreditedTotal,ClosingBalance,ENDBANKACC")
	);
	TagsHeader = CreateMapFromString(
		Upper("FormatVersion,Encoding,Sender,Recipient,CreationDate,CreationTime,StartDate,EndDate")
	);
	StructureTitle = New Structure(
		Upper("FormatVersion,Encoding,Sender,Recipient,CreationDate,CreationTime,StartDate,EndDate")
	);
	ImportTitle = StructureTitle;
	ImportExchangeSign = False;
	IsFoundEndFile = False;
	ImportDocumentsKinds = New Array;
	BankAccountsToImport.Clear();
	DocumentsForImport.Clear();
	
	// We fill the primary data structure.               //АТ здесь начинается разбор текста файла импорта.
	
	If ValueIsFilled(Object.ExternalDataProcessor) Then

		ParametersOfDataProcessor = New Structure("CommandID, AdditionalInformationProcessorRef, BankAccount, ImportTextForParsing, DocumentsForImport" ); 
		
		//Обязательные параметры дополнительных отчетов и обработок
		ParametersOfDataProcessor.CommandID                           = "ImportFromClientBankExternalDP";
		ParametersOfDataProcessor.AdditionalInformationProcessorRef   = Object.ExternalDataProcessor;
		
		//Параметры для внешней обработки обмена с банком
		ParametersOfDataProcessor.BankAccount                     	  = Object.BankAccount;  		//bank account
		ParametersOfDataProcessor.ImportTextForParsing                = ImportTextForParsing;
		
		//Возвращаемые значения
		//ParametersOfDataProcessor.StartPeriod = Date(1,1,1);
		//ParametersOfDataProcessor.EndPeriod   = Date(1,1,1);
		ParametersOfDataProcessor.DocumentsForImport                  = DocumentsForImport; //Table of documents
		
		AdditionalReportsAndDataProcessors.RunCommand( ParametersOfDataProcessor ); //Вызываем обработку и заполняем возвращаемые значения в ParametersOfDataProcessor
					
		WarningText = ParametersOfDataProcessor.ExecutionResult.OutputMessages.Text;

		If ValueIsFilled(WarningText) Then
			
			Message = New UserMessage();
		    MessageText = NSTR("ru='Ошибка: ';en='Error: '")+WarningText;
			//Message.Field = "Nomenclature[10].Count";
		    Message.Text = MessageText;
			//Message.SetData(DataObject);
		    Message.Message();
			return MessageText;
		
		EndIf;
	
	Else
		BankAccountsToImport.Clear();
		DocumentsForImport.Clear();
		MessageText = NStr("en='External Data Processor is not assigned!';ru='Не назначена внешняя обработка загрузки!'");
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
		return MessageText;
	EndIf;
	
	//AT begin Обрабатываем загруженные внешней обработкой документы
	// We sequentially process each imported string.
	LineNumber = 0;
	For Each DocumentRow IN DocumentsForImport Do
		
		// We recognize attributes.
		// If in the file there are statements of payment documents of several
		// accounts, then we recognize and display only those that
		// were exported according to the specified bank account.
		If DocumentRow.PayerAccount = Object.BankAccount.AccountNo
		 OR DocumentRow.PayeeAccount = Object.BankAccount.AccountNo Then
			RecognizeDataInDocumentRow(DocumentRow);
			LineNumber = LineNumber + 1;
			DocumentRow.LineNumber = LineNumber;
			
			// Each attribute (= column) should be checked for empty value.
			For Each LoadColumn IN DocumentsForImport.Columns Do
				CheckForBlankImportValue(
					DocumentRow,
					LoadColumn.Name,
					LoadColumn.Title,
					ImportIsNotEmpty
				);
			EndDo;
			
			If TypeOf(DocumentRow.Counterparty) = Type("String")
			 OR TypeOf(DocumentRow.CounterpartyAccount) = Type("String") Then
				
				// We add attributes in tabular section for further use.
				ListOfNotFound(DocumentRow, Object.BankAccount, CounterpartyTable);
				
			EndIf;
			
		Else
			
			// We mark other items for further deletion.
			DocumentRow.LineNumber = 0;
			
		EndIf;
	EndDo;
	
	// We delete unnecessary rows from a table.
	Quantity = DocumentsForImport.Count() - 1;
	For Ct = 0 to Quantity Do
		If DocumentsForImport[Quantity - Ct].LineNumber = 0 Then
			DocumentsForImport.Delete(Quantity - Ct);
		EndIf;
	EndDo;
	//AT end
	
	
	
	//АТ Здесь начинается обработка полученных документов 
	For Each DocumentRow IN DocumentsForImport Do
		DocumentRow.Import = IsBlankString(DocumentRow.ErrorsDescriptionFull);
		DocumentRow.PaymentDestination = TrimAll(DocumentRow.PaymentDestination);
		DocumentRow.PictureNumber = ?(IsBlankString(DocumentRow.ErrorsDescriptionFull), 0, 1);
		DocumentRow.AdvanceFlag = True;
		FillAmountsAllocatedAtServer(DocumentRow);
	EndDo;
	
	Object.Import.Clear();
	Object.Import.Load(DocumentsForImport);
	
	Object.ImportBankAccounts.Clear();
	Object.ImportBankAccounts.Load(BankAccountsToImport);
	
	Return "";
	
EndFunction // FillDocumentsForImport()

Function FillDocumentsForImportOLD(ImportTextForParsing)
	
	CounterpartyTable.GetItems().Clear();
	
	// We prepare the data processing structures.
	DocumentsForImport = Object.Import.Unload();
	ImportExportable = GenerateMapOfItemsBeingImported();
	ImportIsNotEmpty = Undefined;
	ImportBlankPaymentOrder = Undefined;
	ImportBlankPaymentOrderBudget = Undefined;
	
	BankAccountsToImport = Object.ImportBankAccounts.Unload();
	
	GenerateMapsOFNotEmptyItemsOnImport(
		ImportIsNotEmpty,
		ImportBlankPaymentOrder,
		ImportBlankPaymentOrderBudget
	);
	SettlementsAccountsTags = CreateMapFromString(
		Upper("StartDate,EndDate,BankAcc,OpeningBalance,DebitedTotal,CreditedTotal,ClosingBalance,ENDBANKACC")
	);
	TagsHeader = CreateMapFromString(
		Upper("FormatVersion,Encoding,Sender,Recipient,CreationDate,CreationTime,StartDate,EndDate")
	);
	StructureTitle = New Structure(
		Upper("FormatVersion,Encoding,Sender,Recipient,CreationDate,CreationTime,StartDate,EndDate")
	);
	ImportTitle = StructureTitle;
	ImportExchangeSign = False;
	IsFoundEndFile = False;
	ImportDocumentsKinds = New Array;
	BankAccountsToImport.Clear();
	DocumentsForImport.Clear();
	
	// We fill the primary data structure.
	ImportLineCount = StrLineCount(ImportTextForParsing);
	ImportCurrentRow = 1;
	While ImportCurrentRow <= ImportLineCount Do
		Str = GetImportString(ImportCurrentRow, ImportLineCount, ImportTextForParsing);
		
		// SECTIONDOCUMENT.
		If Left(Upper(TrimAll(Str)), 14) = "SectionDocument" Then
			Value = "";
			Tag = "";
			ParseTagString(Str, Tag, Value);
			If Tag = "SectionDocument" Then
				DocumentsNewRow = DocumentsForImport.Add();
				DocumentsNewRow.Operation = Value;
				If Not ImportDocumentSection(DocumentsNewRow, ImportCurrentRow, ImportLineCount, ImportTextForParsing, ImportExportable) Then
					Return "";
				EndIf;
			Else
				MessageText = NStr("en='The import file structure is broken, the %Import% line: %LineNum%';
									|ru='Нарушена структура файла импорта, строка %Import%: %LineNum%'");
				MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
				MessageText = StrReplace(MessageText, "%LineNum%", Str);
				Return MessageText;
			EndIf;
		
		// SECTIONBANKACC.
		ElsIf Left(Upper(TrimAll(Str)), 14) = "SECTIONBANKACC" Then
			
			StringBAAccounts = BankAccountsToImport.Add();
			If Not ImportBankAccSection(StringBAAccounts, ImportCurrentRow, ImportLineCount, ImportTextForParsing, SettlementsAccountsTags) Then
				MessageText = NStr("en='Import file structure is broken in the account description section. Line: %Import%';
									|ru='Нарушена структура файла импорта в секции описания расчетного счета! Строка: %Import%'");
				MessageText = StrReplace(MessageText, "%Import%", (ImportCurrentRow - 1));
				Return MessageText;
			EndIf;
			If Object.BankAccount.AccountNo <> StringBAAccounts.BankAcc Then
				BankAccountsToImport.Delete(StringBAAccounts);
			EndIf;
			
		// BankAcc.
		ElsIf Left(Upper(TrimAll(Str)), 8) = "BANKACC" Then
			
			Value = "";
			Tag = "";
			ParseTagString(Str, Tag, Value);
			
			If Tag = "BANKACC" Then
				Query = New Query;
				Query.Text =
				"SELECT
				|	BankAccounts.Ref,
				|	BankAccounts.Owner
				|FROM
				|	Catalog.BankAccounts AS BankAccounts
				|WHERE
				|	VALUETYPE(BankAccounts.Owner) = Type(Catalog.Companies)
				|	AND BankAccounts.AccountNo = &AccountNo
				|	AND Not BankAccounts.DeletionMark";
				Query.SetParameter("AccountNo", Value);
				Selection = Query.Execute().Select();
				If Selection.Next() Then
					FoundBankAccount = Selection.Ref;
					If ValueIsFilled(Object.BankAccount)
					   AND FoundBankAccount <> Object.BankAccount Then
						If Object.BankAccount.AccountNo = Value Then
							MessageText = NStr("en='The account in the file header (%Value%) is different from those you specified.';
												|ru='В заголовке файла указан счет (%Value%) отличный от указанного!'");
						Else
							MessageText = NStr("en='There are several bank accounts of companies with the same number in the base.';
												|ru='В базе есть несколько банковский счетов организаций с одинаковым номером!'");
						EndIf;
						MessageText = StrReplace(MessageText, "%Value%", Value);
						Return MessageText;
					Else
						Object.Company = Selection.Owner;
						Object.BankAccount = FoundBankAccount;
						ThisForm.Title = "Importing account statements: " + FoundBankAccount.Description;
					EndIf;
					StringBAAccounts = BankAccountsToImport.Find(Value, "BankAcc");
					If StringBAAccounts = Undefined Then
						StringBAAccounts = BankAccountsToImport.Add();
						StringBAAccounts.BankAcc = Value;
					EndIf;
				Else
					MessageText = NStr("en='In the file title there is an account that does not belong to the company: %Value%.';
										|ru='В заголовке файла указан счет, не принадлежащий организации: %Value%!'");
					MessageText = StrReplace(MessageText, "%Value%", Value);
					Return MessageText;
				EndIf;
			EndIf;
		
		// DOCUMENT.
		ElsIf Left(Upper(TrimAll(Str)), 8) = "DOCUMENT" Then
			ImportDocumentsKinds.Add(Value);
		
		// ENDFILE.
		ElsIf Left(Upper(TrimAll(Str)), 10) = "EndFile" Then
			If Not ImportExchangeSign Then
				MessageText = NStr("en='1C:ClientBankExchange is missing in the import file.';ru='В файле импорта отсутствует признак обмена ""1CClientBankExchange""!'");
				Return MessageText;
			EndIf;
			
			IsFoundEndFile = True;
			LineNumber = 0;
			
			// We sequentially process each imported string.
			For Each DocumentRow IN DocumentsForImport Do
				
				// We recognize attributes.
				// If in the file there are statements of payment documents of several
				// accounts, then we recognize and display only those that
				// were exported according to the specified bank account.
				If DocumentRow.PayerAccount = Object.BankAccount.AccountNo
				 OR DocumentRow.PayeeAccount = Object.BankAccount.AccountNo Then
					RecognizeDataInDocumentRow(DocumentRow);
					LineNumber = LineNumber + 1;
					DocumentRow.LineNumber = LineNumber;
					
					// Each attribute (= column) should be checked for empty value.
					For Each LoadColumn IN DocumentsForImport.Columns Do
						CheckForBlankImportValue(
							DocumentRow,
							LoadColumn.Name,
							LoadColumn.Title,
							ImportIsNotEmpty
						);
					EndDo;
					
					If TypeOf(DocumentRow.Counterparty) = Type("String")
					 OR TypeOf(DocumentRow.CounterpartyAccount) = Type("String") Then
						
						// We add attributes in tabular section for further use.
						ListOfNotFound(DocumentRow, Object.BankAccount, CounterpartyTable);
						
					EndIf;
					
				Else
					
					// We mark other items for further deletion.
					DocumentRow.LineNumber = 0;
					
				EndIf;
			EndDo;
			
			// We delete unnecessary rows from a table.
			Quantity = DocumentsForImport.Count() - 1;
			For Ct = 0 to Quantity Do
				If DocumentsForImport[Quantity - Ct].LineNumber = 0 Then
					DocumentsForImport.Delete(Quantity - Ct);
				EndIf;
			EndDo;
		
		// 1CCLIENTBANKEXCHANGE.
		ElsIf Left(Upper(TrimAll(Str)), 20) = "1CCLIENTBANKEXCHANGE" Then
			ImportExchangeSign = True;
		Else
			ImportHeaderString(
				Str,
				TagsHeader,
				ImportTitle,
				ImportCurrentRow
			);
		EndIf;
		
	EndDo;
	
	If Not IsFoundEndFile Then
		BankAccountsToImport.Clear();
		DocumentsForImport.Clear();
		MessageText = NStr("en='Import file does not correspond to a standard. (The EndFile section is not found).';ru='Файл загрузки не соответствует стандарту (не найдена секция КонецФайла)!'");
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
	EndIf;
	
	For Each DocumentRow IN DocumentsForImport Do
		DocumentRow.Import = IsBlankString(DocumentRow.ErrorsDescriptionFull);
		DocumentRow.PaymentDestination = TrimAll(DocumentRow.PaymentDestination);
		DocumentRow.PictureNumber = ?(IsBlankString(DocumentRow.ErrorsDescriptionFull), 0, 1);
		DocumentRow.AdvanceFlag = True;
		FillAmountsAllocatedAtServer(DocumentRow);
	EndDo;
	
	Object.Import.Clear();
	Object.Import.Load(DocumentsForImport);
	
	Object.ImportBankAccounts.Clear();
	Object.ImportBankAccounts.Load(BankAccountsToImport);
	
	Return "";
	
EndFunction // FillDocumentsForImport()

// Function reads file.
//
&AtClient
Function ReadFile(PathToFileFromSetting)
	
	File = TrimAll(PathToFileFromSetting);
	
	If Object.Encoding = "DOS" Then
		Codin = TextEncoding.OEM;
	//AT begin
	ElsIf Object.Encoding = "OEM" Then
		Codin = TextEncoding.OEM;
	ElsIf Object.Encoding = "ANSI" or Object.Encoding = "Windows" Then
		Codin = TextEncoding.ANSI;
	ElsIf Object.Encoding = "UTF8" Then
		Codin = TextEncoding.UTF8;
	ElsIf Object.Encoding = "UTF16" Then
		Codin = TextEncoding.UTF16;
	//AT end
	Else
		Codin = TextEncoding.ANSI;
	EndIf;
	
	Try
		ReadStream.Read(File, Codin);
	Except
		MessageText = NStr("en='An error occurred while reading the %File% file.';ru='Ошибка чтения файла %File%.'");
		MessageText = StrReplace(MessageText, "%File%", File);
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText);
		Return Undefined;
	EndTry;
	
	If ReadStream.LineCount() < 1 Then
		MessageText = NStr("en='No data in the file.';ru='В файле нет данных!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText);
		Return Undefined;
	EndIf;
	
	Return ReadStream.GetText();
	
EndFunction // ReadFile()

// Function reads data from a file.
//
&AtClient
Procedure ReadDataFromFile()
			
	// We get source data.
	ImportTextForParsing = ReadFile(Object.ImportFile);		
		
	If ImportTextForParsing = Undefined Then
		MessageText = NStr("en='Import file does not contain data.';ru='Файл загрузки не содержит данных!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText);
		Return;
	EndIf;
		
	WarningText = FillDocumentsForImport(ImportTextForParsing);
	
	If ValueIsFilled(WarningText) Then
		ShowMessageBox(Undefined,WarningText);
	EndIf;
	
EndProcedure // ReadDataFromFile()

&AtClient
Function PeriodFilledWith()
	
	PeriodFilledWith = True;
	
	If Not ValueIsFilled(Object.StartPeriod) Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Period start date is not filled in';ru='Не заполнена дата начала периода'")
			,, "Object.StartPeriod");
		PeriodFilledWith = False;
	EndIf;
	
	If Not ValueIsFilled(Object.EndPeriod) Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Period end date is not filled in';ru='Не заполнена дата окончания периода'")
			,, "Object.EndPeriod");
		PeriodFilledWith = False;
	EndIf;
	
	Return PeriodFilledWith;
	
EndFunction

&AtServerNoContext
Function GetAccountNo(BankAccount)
	
	If ValueIsFilled(BankAccount) Then
		Return CommonUse.GetAttributeValue(BankAccount, "AccountNo");
	EndIf;
	
	Return "";
	
EndFunction

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
		ThisForm.Title = "Importing account statements: " + Parameters.BankAccountOfTheCompany.Description;
	EndIf;
	
	If Parameters.Property("PathToFile") Then
		Object.ImportFile = Parameters.PathToFile;
	EndIf;
	
	If Parameters.Property("CFItemIncoming") Then
		Object.CFItemIncoming = Parameters.CFItemIncoming;
	EndIf;
	
	If Parameters.Property("CFItemOutgoing") Then
		Object.CFItemOutgoing = Parameters.CFItemOutgoing;
	EndIf;
	
	If Parameters.Property("PostImported") Then
		Object.PostImported = Parameters.PostImported;
	EndIf;
	
	If Parameters.Property("FillDebtsAutomatically") Then
		Object.FillDebtsAutomatically = Parameters.FillDebtsAutomatically;
	EndIf;
	
	If Parameters.Property("Application") Then
		Object.ExternalDataProcessor = Parameters.Application;
	EndIf;
	
	If Not ValueIsFilled(Object.StartPeriod) Then
		Object.StartPeriod = CurrentDate();
	EndIf;
	
	If Not ValueIsFilled(Object.EndPeriod) Then
		Object.EndPeriod = CurrentDate();
	EndIf;
	
	If Parameters.Property("Encoding") Then
		Object.Encoding = Parameters.Encoding;
	EndIf;
	
	If Not ValueIsFilled(Object.Encoding) Then
		Object.Encoding = "Windows";
	EndIf;
	
	If Parameters.Property("FormatVersion") Then
		Object.FormatVersion = Parameters.FormatVersion;
	EndIf;
	
	If Not ValueIsFilled(Object.FormatVersion) Then
		Object.FormatVersion = "1.02";
	EndIf;
	
	If Not ValueIsFilled(Object.CFItemIncoming) Then
		Object.CFItemIncoming = Catalogs.CashFlowItems.PaymentFromCustomers;
	EndIf;
	If Not ValueIsFilled(Object.CFItemOutgoing) Then
		Object.CFItemOutgoing = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;
	
	
	If Parameters.Property("AddressOfFileForProcessing") Then
		ImportFile = GetFromTempStorage(Parameters.AddressOfFileForProcessing);   //!!!!!
		If TypeOf(ImportFile) = Type("BinaryData") Then
			Try
				TempFileName = GetTempFileName("txt");
				ImportFile.Write(TempFileName);
				TextDocument = New TextDocument();
				TextDocument.Read(TempFileName);
				ImportFile = TextDocument.GetText();
				DeleteFiles(TempFileName);
			Except
				WriteLogEvent(NStr("en='Exchange with bank. Temporary file';ru='Обмен с банком.Временный файл'"), 
				EventLogLevel.Error,
				,
				,
				StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Cannot save temporary file to disk due to: %1';ru='Не удалось сохранение временного файла на диск по причине: %1'"),
				ErrorDescription()));
				Return;
			EndTry;
		EndIf;
		
		ReadStream.SetText(ImportFile);                                       //!!!!!
		
		WarningText = FillDocumentsForImport(ImportFile);
		
		Items.NotFoundAttributes.Visible = (CounterpartyTable.GetItems().Count() > 0);
		
	EndIf;
		
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(WarningText) Then
		ShowMessageBox(Undefined,WarningText);
		Cancel = True;
	EndIf;
	
	ValidTypes = New TypeDescription("CatalogRef.Counterparties", ,);
	Items.ImportCounterparty.TypeRestriction = ValidTypes;
	
	ValidTypes = New TypeDescription("CatalogRef.CounterpartyContracts", ,);
	Items.ImportContract.TypeRestriction = ValidTypes;
	
	Notification = New NotifyDescription("BeginEnableExtensionFileOperationsEnd", ThisObject, New Structure("FormAttribute", "ImportFile"));
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure // OnOpen()

&AtClient
Procedure BeginEnableExtensionFileOperationsEnd(Attached, AdditionalParameters) Export
	
	ThisForm.FileOperationsExtensionConnected = Attached;
	If ThisForm.FileOperationsExtensionConnected Then
		If Not ValueIsFilled(Object.ImportFile) Then
			Object.ImportFile = "c:\kl_to_1c.txt";
		EndIf;
	Else
		Object.ImportFile = "";
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - The ImportCheckAll command handler.
//
&AtClient
Procedure ImportCancelAllExecute(Command)
	
	SetFlags(Object.Import, "Import", True, True);
	
EndProcedure // ImportCancelExecuteAll()

// Procedure - The ImportUnmarkAll command handler.
//
&AtClient
Procedure ImportUncheckAllExecute(Command)
	
	SetFlags(Object.Import, "Import", False, True);
	
EndProcedure // ImportUnmarkAllExecute()

// Procedure - The NotFoundAttributesImportMarkAll command handler.
//
&AtClient
Procedure NotFoundAttributesImportingMarkAll(Command)
	
	SetFlags(CounterpartyTable.GetItems(), "Import", True, False);
	
EndProcedure // NotFoundAttributesImportMarkAll()

// Procedure - The NotFoundUnmarkAllAttributes command handler.
//
&AtClient
Procedure NotFoundsUnmarkAllAttributes(Command)
	
	SetFlags(CounterpartyTable.GetItems(), "Import", False, False);
	
EndProcedure // NotFoundUnmarkAllAttributes()

// Procedure - The ImportRefresh command handler.
//
&AtClient
Procedure ImportUpdateExecute(Command)
	
	If Not CheckFillOfFormAttributes() Then
		
		Return;
		
	EndIf;
	
	ReadDataFromFile();
	Items.NotFoundAttributes.Visible = (CounterpartyTable.GetItems().Count() > 0);
	
EndProcedure // ImportUpdateExecute()

// Procedure - Import command handler.
//
&AtClient
Procedure ImportExecute(Command)
	
	ClearMessages();
	
	If Not CheckFillOfFormAttributes() Then
		
		Return;
		
	EndIf;
	
	If Object.Import.Count() > 0 Then
		
		DataLoadFromFile();
		
	Else
		
		ShowMessageBox(Undefined,NStr("en='Document list for import is empty.';ru='Список документов для загрузки пуст.'"));
		
	EndIf;
	
EndProcedure // ImportExecute()

// Procedure - The CreateCounterparties command handler.
//
&AtClient
Procedure CreateCounterparties(Command)
	
	CreateNewCounterparty();
	
	ReadDataFromFile();
	
	Items.NotFoundAttributes.Visible = (CounterpartyTable.GetItems().Count() > 0);
	
EndProcedure // CreateCounterparties()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTIONS EVENT HANDLERS

// Procedure - The Selection event handler of the Import tabular section.
//
&AtClient
Procedure ImportSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ImportExport" Then
		StandardProcessing = False;
		Items.ImportTable.CurrentData.Import = Not (Items.ImportTable.CurrentData.Import);
	ElsIf Field.Name = "ImportPictureNumber" Then 
		StandardProcessing = False;
		If ValueIsFilled(Items.ImportTable.CurrentData.ErrorsDescriptionFull) Then
			ShowMessageBox(Undefined,Items.ImportTable.CurrentData.ErrorsDescriptionFull);
		Else
			ShowMessageBox(Undefined,NStr("en='Document is ready for import.';ru='Документ готов к загрузке!'"));
		EndIf;
	ElsIf Field.Name = "ImportPaymentDestination" Then
		StandardProcessing = False;
		ShowMessageBox(Undefined,Items.ImportTable.CurrentData.PaymentDestination);
	ElsIf ValueIsFilled(Items.ImportTable.CurrentData.Document)
		AND (Field.Name = "ImportDocumentName"
		OR Field.Name = "ImportDocDate"
		OR Field.Name = "ImportDocNumber"
		OR Field.Name = "ImportDocumentSum"
		OR Field.Name = "ImportAmountDebited"
		OR Field.Name = "ImportAmountWrittenOff") Then
		OpenForm("Document." + Items.ImportTable.CurrentData.DocumentKind + ".ObjectForm",
			New Structure("Key", Items.ImportTable.CurrentData.Document),
			Items.ImportTable.CurrentData.Document
		);
	EndIf;
	
EndProcedure // ImportSelection()

// Procedure creates a new counterparty.
//
&AtServer
Procedure CreateNewCounterparty()
	
	For Each Item IN CounterpartyTable.GetItems() Do
		
		If Item.Import Then
			FormAttributeToValue("Object").CreateCounterparty(Item).IsEmpty();
		EndIf;
		
	EndDo;
	
EndProcedure // CreateNewCounterparty()

// Procedure - The StartChoice event handler for the Order field of the Import list.
//
&AtClient
Procedure ImportOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRowOfTabularSection = Items.ImportTable.CurrentData;
	If TypeOf(CurrentRowOfTabularSection.Counterparty) = Type("String") Then
		
		StandardProcessing	= False;
		
		MessageText			= NStr("en='Counterparty is not identified. Cannot select the order.';ru='Контрагент не идентифицирован, выбор заказа не возможен.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure //ImportOrderStartChoice()

// Procedure - the OnChange event handler of the Import list.
//
&AtClient
Procedure ImportExportOnChange(Item)
	
	CurRow = Items.ImportTable.CurrentData;
	FillAmount76AtClient(CurRow)
	
EndProcedure // ImportingImportOnChange()

// Filling the amount of marked items.
//
&AtClient
Procedure FillAmount76AtClient(CurRow)
	
	CurRow.AmountReceiptAllocated = ?(CurRow.Import, CurRow.AmountDebited, 0);
	CurRow.AmountWriteOffAllocated = ?(CurRow.Import, CurRow.AmountCredited, 0);
	CurRow.DocumentAmountAllocated = ?(CurRow.Import, CurRow.DocumentAmount, 0);
	
EndProcedure

// Filling the amount of marked items.
//
&AtServer
Procedure FillAmountsAllocatedAtServer(CurRow)
	
	CurRow.AmountReceiptAllocated = ?(CurRow.Import, CurRow.AmountDebited, 0);
	CurRow.AmountWriteOffAllocated = ?(CurRow.Import, CurRow.AmountCredited, 0);
	CurRow.DocumentAmountAllocated = ?(CurRow.Import, CurRow.DocumentAmount, 0);
	
EndProcedure

// Procedure - the Setting command handler.
//
&AtClient
Procedure Setting(Command)
	
	OpenForm("DataProcessor.ClientBank.Form.FormSetting",
		New Structure(
			"Script, FormatVersion, ExternalDataProcessor, PostImported, FillDebtsAutomatically, UUID",
			Object.Encoding, Object.FormatVersion, Object.ExternalDataProcessor, Object.PostImported, Object.FillDebtsAutomatically, UUID
		)
	);
	
EndProcedure // Setting()

// Procedure - form alert processing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingsChange" + UUID Then
		Object.Encoding = Parameter.Encoding;
		Object.ExternalDataProcessor = Parameter.DataProcessor;
		Object.FormatVersion = Parameter.FormatVersion;
		Object.PostImported = Parameter.PostImported;
		Object.FillDebtsAutomatically = Parameter.FillDebtsAutomatically;
	EndIf;
	
EndProcedure // NotificationProcessing()

//( elmi #17 (112-00003) 
&AtServer
Procedure FillTableFromExternalDataProcessor(ImportStream)

Object.Import.Clear();

For Each String IN ImportStream Do
   
	NewString = Object.Import.Add();
	
	RecognizeDataInDocumentRow(String);
	
	If TypeOf(String.Counterparty) = Type("String")
		OR TypeOf(String.CounterpartyAccount) = Type("String") Then
		
		// We add attributes in tabular section for further use.
		ListOfNotFound(String, Object.BankAccount, CounterpartyTable);
		
	EndIf;

    FillPropertyValues(NewString, String);
	
EndDo;

FormAttributeToValue("Object");

EndProcedure
//) elmi

//( elmi #17 (112-00003)	
&AtServer
Procedure RunCommandOnServer(ParametersDataProcessors) Export
	
	AdditionalReportsAndDataProcessors.RunCommand( ParametersDataProcessors );
	
EndProcedure	
//) elmi
