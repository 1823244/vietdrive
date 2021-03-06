﻿// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Encoding") Then
		Encoding = Parameters.Encoding;
	Else
		Items.Encoding.Visible = False;
	EndIf;
	
	If Parameters.Property("FormatVersion") Then
		FormatVersion = Parameters.FormatVersion;
	Else
		Items.FormatVersion.Visible = False;
	EndIf;
	
	If Parameters.Property("ExternalDataProcessor") Then
		ExternalDataProcessor = Parameters.ExternalDataProcessor;
	Else
		Items.ExternalDataProcessor.Visible = False;
	EndIf;
	
	If Parameters.Property("CFItemOutgoing") Then
		CFItemOutgoing = Parameters.CFItemOutgoing;
	Else
		Items.CFItemOutgoing.Visible = False;
	EndIf;

	If Parameters.Property("CFItemIncoming") Then
		CFItemIncoming = Parameters.CFItemIncoming;
	Else
		Items.CFItemIncoming.Visible = False;
	EndIf;

	If Parameters.Property("PostImported") Then
		PostImported = Parameters.PostImported;
	Else
		Items.PostImported.Visible = False;
	EndIf;
	
	If Parameters.Property("FillDebtsAutomatically") Then
		FillDebtsAutomatically = Parameters.FillDebtsAutomatically;
	Else
		Items.FillDebtsAutomatically.Visible = False;
	EndIf;
	
	If Parameters.Property("ExportFile") Then
		ExportFile = Parameters.ExportFile;
	Else
		Items.ExportFile.Visible = False;
	EndIf;

	If Parameters.Property("ImportFile") Then
		ImportFile = Parameters.ImportFile;
	Else
		Items.ImportFile.Visible = False;
	EndIf;
	
	Items.GroupExchangeKinds.CurrentPage = Items.GroupExchangeThroughFile;
	DirectMessageExchange                    = "";
	
	IDOwner = Parameters.UUID;
	
EndProcedure // OnCreateAtServer

// Procedure - command DataProcessor Ok.
//
&AtClient
Procedure Ok(Command)
	
	ReturnParameters = New Structure(
	//( elmi #17 (112-00003) 
	//"Script, Application, CFItemIncoming, CFItemOutgoing, PostImported, FillDebtsAutomatically, ExportFile, ImportFile, FormatVersion",
	"Encoding, ExternalDataProcessor, CFItemIncoming, CFItemOutgoing, PostImported, FillDebtsAutomatically, ExportFile, ImportFile, FormatVersion",
	//) elmi
	Encoding, ExternalDataProcessor, CFItemIncoming, CFItemOutgoing, PostImported, FillDebtsAutomatically, ExportFile, ImportFile, FormatVersion
	);
	Notify("SettingsChange" + IDOwner, ReturnParameters);
	Close();
	
EndProcedure // Ok()

&AtClient
Procedure ExportFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	Notification = New NotifyDescription("BeginEnableExtensionFileOperationsEnd", ThisObject, New Structure("FormAttribute", "ExportFile"));
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

&AtClient
Procedure ImportFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	Notification = New NotifyDescription("BeginEnableExtensionFileOperationsEnd", ThisObject, New Structure("FormAttribute", "ImportFile"));
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

&AtClient
Procedure BeginEnableExtensionFileOperationsEnd(Attached, AdditionalParameters) Export
	
	If Not Attached Then
		Notification = New NotifyDescription("BeginInstallFileSystemExtensionEnd", ThisObject, AdditionalParameters);
		MessageText = NStr("en='To continue, you need to install an extension for 1C:Enterprise web client. Install?';ru='Для продолжении работы необходимо установить расширение для веб-клиента ""1С:Предприятие"". Установить?'");
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo); 
	EndIf;
	
	Mode = FileDialogMode.Open;
	
	FileOpeningDialog = New FileDialog(Mode);
	FileOpeningDialog.FullFileName = ImportFile;
	Filter = "Text file(*.txt)|*.txt|Xml file(*.xml)|*.xml|(*.*)|*.*|";
	FileOpeningDialog.Filter = Filter;
	FileOpeningDialog.Multiselect = False;
	FileOpeningDialog.Title = NStr("en='Select file';ru='Выберите файл'");
	
	Notification = New NotifyDescription("FileOpeningDialogEnd", ThisObject, AdditionalParameters);
	FileOpeningDialog.Show(Notification);
	
EndProcedure

&AtClient
Procedure FileOpeningDialogEnd(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined AND SelectedFiles.Count() > 0 Then
		If AdditionalParameters.FormAttribute = "ImportFile" Then
			ImportFile = SelectedFiles[0];
		Else
			ExportFile = SelectedFiles[0];
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeginInstallFileSystemExtensionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		BeginInstallFileSystemExtension();
	EndIf;
	
EndProcedure
