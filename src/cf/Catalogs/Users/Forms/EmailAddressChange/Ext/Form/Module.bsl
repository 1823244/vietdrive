﻿#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	User = Parameters.User;
	ServiceUserPassword = Parameters.ServiceUserPassword;
	OldEmail = Parameters.OldEmail;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChangeEmailAddress(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	QuestionText = "";
	If Not ValueIsFilled(OldEmail) Then
		QuestionText =
			NStr("en='Email address of service user is changed.
		|The subscriber owners or administrators will not be able to change the user parameters any more.';ru='Адрес электронной почты пользователя сервиса изменен.
		|Владельцы и администраторы абонента больше не смогут изменять параметры пользователя.'")
			+ Chars.LF
			+ Chars.LF;
	EndIf;
	QuestionText = QuestionText + NStr("en='Change the email address?';ru='Выполнить изменение адреса электронной почты?'");
	
	ShowQueryBox(
		New NotifyDescription("ChangeEmailEnd", ThisObject),
		QuestionText,
		QuestionDialogMode.YesNoCancel);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure CreateRequestToChangeEmail()
	
	UsersService.WhenYouCreateQueryByMail(NewEmail, User, ServiceUserPassword);
	
EndProcedure

&AtClient
Procedure ChangeEmailEnd(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.Yes Then
		
		CreateRequestToChangeEmail();
		
		ShowMessageBox(
			New NotifyDescription("Close", ThisObject),
			NStr("en='The email with confirmation request was sent to the specified address.
		|Email will be changed only after confirmation of the request by a user.';ru='На указанный адрес отправлено письмо с запросом на подтверждение.
		|Почта будет изменена только после подтверждения запроса пользователем.'"));
		
	ElsIf Response = DialogReturnCode.No Then
		Close();
	EndIf;
	
EndProcedure

#EndRegion
