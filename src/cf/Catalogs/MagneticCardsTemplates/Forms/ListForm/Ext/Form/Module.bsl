﻿
#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	// Peripherals
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		ErrorDescription = "";

		SupporTypesVO = New Array();
		SupporTypesVO.Add("MagneticCardReader");

		If Not EquipmentManagerClient.ConnectEquipmentByType(UUID, 
			SupporTypesVO, ErrorDescription) Then
			MessageText = NStr("en='An error occurred while
								|connecting peripherals: ""%ErrorDescription%"".';ru='При подключении оборудования
								|произошла ошибка: ""%ErrorDescription%"".'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	// End Peripherals
EndProcedure

&AtClient
Procedure OnClose()
	// Peripherals
	SupporTypesVO = New Array();
	SupporTypesVO.Add("MagneticCardReader");

	EquipmentManagerClient.DisableEquipmentByType(UUID, 
	 	SupporTypesVO);
	// End Peripherals
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "TracksData" Then
			                  
			// Open the matching templates.
			ClearMessages();
			If Parameter[1][3] = Undefined
				OR Parameter[1][3].Count() = 0 Then
				CommonUseClientServer.MessageToUser(NStr("en='It was not succeeded to read fields. 
		|Perhaps, template has been configured incorrectly.';ru='Не удалось прочитать поля. 
		|Возможно, шаблон настроен неверно.'"));
			Else
				TemplateFound = False;
				For Each curTemplate IN Parameter[1][3] Do
					TemplateFound = True;
					OpenForm("Catalog.MagneticCardsTemplates.ObjectForm", New Structure("Key", curTemplate.Pattern));
				EndDo;
				If Not TemplateFound Then
					CommonUseClientServer.MessageToUser(NStr("en='Code does not match this template. 
		|Perhaps, template has been configured incorrectly.';ru='Код не соответствует данному шаблону. 
		|Возможно, шаблон настроен неверно.'"));
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	// End Peripherals
EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
	If IsInputAvailable() Then
		
		DetailsEvents = New Structure();
		ErrorDescription  = "";
		DetailsEvents.Insert("Source", Source);
		DetailsEvents.Insert("Event",  Event);
		DetailsEvents.Insert("Data",   Data);
		
		Result = EquipmentManagerClient.GetEventFromDevice(DetailsEvents, ErrorDescription);
		If Result = Undefined Then 
			MessageText = NStr("en='An error occurred during the processing of external event from the device:';ru='При обработке внешнего события от устройства произошла ошибка:'")
								+ Chars.LF + ErrorDescription;
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			NotificationProcessing(Result.EventName, Result.Parameter, Result.Source);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
