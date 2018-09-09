// Procedure - command handler LoadFromFile.
//
&AtClient
Procedure LoadFromFile(Command)
	
		
	SmallBusinessClient.ImportDataFromStatementFile(
			UUID,
			Object.ImportFile,
			Object.Company,
			Object.BankAccount,
			Object.CFItemIncoming,
			Object.CFItemOutgoing,
			Object.PostImported,
			Object.FillDebtsAutomatically,
			//AT Object.Application,
			Object.ExternalDataProcessor, //AT 
			Object.Encoding,
			Object.FormatVersion
		);
		
EndProcedure // LoadFromFile()

// Procedure - command handler SaveNewTasks.
//
&AtClient
Procedure SaveNewTasks(Command)
	
	OpenForm(
		"DataProcessor.ClientBank.Form.FormExport",
		New Structure(
			//AT "Company, BankAccountOfTheCompany, ExportFile, Application, Script, FormatVersion",
			"Company, BankAccountOfTheCompany, ExportFile, ExternalDataProcessor, Script, FormatVersion", //AT 
			Object.Company,
			Object.BankAccount,
			Object.ExportFile,
			//AT Object.Application,
			Object.ExternalDataProcessor,//AT 
			Object.Encoding,
			Object.FormatVersion
		)
	);
	
EndProcedure // SaveNewTasks()

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RefreshFilterBankAccounts();
	
	If Not ValueIsFilled(Object.Encoding) Then
		Object.Encoding = "Windows";
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
	
EndProcedure // OnCreateAtServer()

// Procedure saves the form settings.
//
&AtServer
Procedure SaveFormSettings()
	
	Settings = New Map;
	Settings.Insert("ImportFile", Object.ImportFile);
	Settings.Insert("ExportFile", Object.ExportFile);
	//AT Settings.Insert("Application", Object.Application);
	Settings.Insert("ExternalDataProcessor", Object.ExternalDataProcessor); //AT
	Settings.Insert("CFItemOutgoing", Object.CFItemOutgoing);
	Settings.Insert("CFItemIncoming", Object.CFItemIncoming);
	Settings.Insert("PostImported", Object.PostImported);
	Settings.Insert("FillDebtsAutomatically", Object.FillDebtsAutomatically);
	Settings.Insert("Encoding", Object.Encoding);
	Settings.Insert("FormatVersion", Object.FormatVersion);
	
	SystemSettingsStorage.Save("DataProcessor.ClientBank.Form.DefaultForm/" + ?(ValueIsFilled(Object.BankAccount), GetURL(Object.BankAccount), "BankAccountIsNotSpecified"), "ExportingInClientbank", Settings);
	
EndProcedure // SaveFormSettings()

// Procedure - command handler FilterByAccountClick.
//
&AtClient
Procedure FilterByAccountClick(Item)
	
	Filter = New Structure("IsCompanyAccount", True);
	OpenForm("Catalog.BankAccounts.Form.ChoiceFormWithoutOwner", New Structure("CurrentRow, Filter", Object.BankAccount, Filter), ThisForm);
	
EndProcedure // FilterByAccountClick()

// Procedure - event handler ChoiceProcessing of form.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("CatalogRef.BankAccounts") Then
		Object.BankAccount = ValueSelected;
		RefreshFilterBankAccounts();
	EndIf;
	
EndProcedure // ChoiceProcessing()

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
	
	Settings = SystemSettingsStorage.Load("DataProcessor.ClientBank.Form.DefaultForm/" + ?(ValueIsFilled(Object.BankAccount), GetURL(Object.BankAccount), "BankAccountIsNotSpecified"), "ExportingInClientbank");
	
	If Settings <> Undefined Then
		Object.ExportFile = Settings.Get("ExportFile");
		Object.ImportFile = Settings.Get("ImportFile");
		//AT Object.Application = Settings.Get("Application");
		Object.ExternalDataProcessor = Settings.Get("ExternalDataProcessor");  //AT
		Object.CFItemOutgoing = Settings.Get("CFItemOutgoing");
		Object.CFItemIncoming = Settings.Get("CFItemIncoming");
		Object.PostImported = Settings.Get("PostImported");
		If Settings.Get("FillDebtsAutomatically") = Undefined Then
			Object.FillDebtsAutomatically = True;
		Else
			Object.FillDebtsAutomatically = Settings.Get("FillDebtsAutomatically");
		EndIf;
		Object.Encoding = Settings.Get("Encoding");
		If Not ValueIsFilled(Object.Encoding) Then
			Object.Encoding = "Windows";
		EndIf;
		Object.FormatVersion = Settings.Get("FormatVersion");
		If Not ValueIsFilled(Object.FormatVersion) Then
			Object.FormatVersion = "1.02";
		EndIf;
	EndIf;
	
EndProcedure // ImportFormSettings()

// Updates the bank accounts filter.
//
&AtServer
Procedure RefreshFilterBankAccounts()
	
	Object.Company = Object.BankAccount.Owner;
	
	ImportFormSettings();
	
	Query = New Query(
	"SELECT
	|	BankAccounts.Ref
	|FROM
	|	Catalog.BankAccounts AS BankAccounts
	|WHERE
	|	VALUETYPE(BankAccounts.Owner) = Type(Catalog.Companies)
	|	AND Not BankAccounts.DeletionMark");
	
	ResultSelection = Query.Execute().Select();
	
	FewAccounts = ResultSelection.Next();
	
	FilterValueFilled = ValueIsFilled(Object.BankAccount);
	
	// Visible setting.
	If FewAccounts Then
		Items.ByAllAccounts.Visible = FilterValueFilled;
		Items.FilterByAccount.Visible = True;
	Else
		Items.ByAllAccounts.Visible = False;
		Items.FilterByAccount.Visible = True;
	EndIf;
	
	If ValueIsFilled(Object.BankAccount) Then
				
		Items.FilterByAccount.Title = 
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Bank account: %1';ru='Банковский счет: %1'"),
				Object.BankAccount);
	Else
		Items.FilterByAccount.Title = NStr("en='Bank account: <All>';ru='Банковский счет: <По всем>'")
	EndIf;
	
EndProcedure // RefreshFilterBankAccounts()

// Updates the filter of the bank accounts when record new bank account.
//
&AtClient
Procedure NewWriteProcessing(NewObject, Source, StandardProcessing)
	
	If TypeOf(NewObject) = Type("CatalogRef.BankAccounts") Then
		StandardProcessing = False;
		RefreshFilterBankAccounts();
	EndIf;

EndProcedure // NewWriteProcessing()

// Cancel of the bank account selection.
//
&AtClient
Procedure ByAllAccounts(Command)
	
	Object.BankAccount = PredefinedValue("Catalog.BankAccounts.EmptyRef");
	RefreshFilterBankAccounts();
	
EndProcedure // ByAllAccounts()

// Procedure - command handler Setting.
//
&AtClient
Procedure Settings(Command)
	
	OpenForm("DataProcessor.ClientBank.Form.FormSetting",
	    //AT
		//New Structure(
		//	"Script, Application, FormatVersion, CFItemIncoming, CFItemOutgoing, PostImported, FillDebtsAutomatically, UUID, ExportFile, ImportFile",
		//	Object.Encoding, Object.Application, Object.FormatVersion, Object.CFItemIncoming, Object.CFItemOutgoing, Object.PostImported, Object.FillDebtsAutomatically, UUID, Object.ExportFile, Object.ImportFile
		New Structure(
			"Encoding, ExternalDataProcessor, FormatVersion, CFItemIncoming, CFItemOutgoing, PostImported, FillDebtsAutomatically, UUID, ExportFile, ImportFile",
			Object.Encoding, Object.ExternalDataProcessor, Object.FormatVersion, Object.CFItemIncoming, Object.CFItemOutgoing, Object.PostImported, Object.FillDebtsAutomatically, UUID, Object.ExportFile, Object.ImportFile
		)
	);
	
EndProcedure // Setting()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingsChange" + UUID Then
		Object.ImportFile = Parameter.ImportFile;
		Object.ExportFile = Parameter.ExportFile;
		Object.Encoding = Parameter.Encoding;
		Object.FormatVersion = Parameter.FormatVersion;
		//AT Object.Application = Parameter.Application;
		Object.ExternalDataProcessor = Parameter.ExternalDataProcessor; //AT
		Object.CFItemIncoming = Parameter.CFItemIncoming;
		Object.CFItemOutgoing = Parameter.CFItemOutgoing;
		Object.PostImported = Parameter.PostImported;
		Object.FillDebtsAutomatically = Parameter.FillDebtsAutomatically;
		SaveFormSettings();
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtClient
Procedure InformationDecorationOnDirectExchangeWithBankClick(Item)
	GotoURL("");
EndProcedure














