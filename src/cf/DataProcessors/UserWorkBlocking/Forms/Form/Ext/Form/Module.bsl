﻿&AtClient
Var AdministrationParameters, LockCurrentValue;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ThisIsFileBase = CommonUse.FileInfobase();
	ThisIsSystemAdministrator = Users.InfobaseUserWithFullAccess(, True);
	SessionWithoutSeparator = CommonUseReUse.SessionWithoutSeparator();
	
	If ThisIsFileBase Or Not ThisIsSystemAdministrator Then
		Items.DisableScheduledJobsGroup.Visible = False;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Or Not Users.RolesAvailable("FullRights") Then
		Items.UnlockCode.Visible = False;
	EndIf;
	
	GetBlockParameters();
	InstallStarterStatusBanUsers();
	RefreshSettingsPage();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ClientConnectedViaWebServer = CommonUseClient.ClientConnectedViaWebServer();
	If InfobaseConnectionsClient.SessionTerminationInProgress() Then
		Items.ModeGroup.CurrentPage = Items.LockStatePage;
		RefreshStatePage(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	InformationAboutLockingSessions = InfobaseConnections.InformationAboutLockingSessions(NStr("en='Not locked.';ru='Блокировка не установлена.'"));
	
	If InformationAboutLockingSessions.LockSessionsPresent Then
		Raise InformationAboutLockingSessions.MessageText;
	EndIf;
	
	NumberOfSessions = InformationAboutLockingSessions.NumberOfSessions;
	
	// Checking of the blocking setting possibility.
	If Object.LockBegin > Object.LockEnding 
		AND ValueIsFilled(Object.LockEnding) Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Lock end date cannot be earlier than lock start date. Lock is not set.';ru='Дата окончания блокировки не может быть меньше даты начала блокировки. Блокировка не установлена.'"),,
			"Object.LockEnding",,Cancel);
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.LockBegin) Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Lock start date is not specified.';ru='Не указана дата начала блокировки.'"),,	"Object.LockBegin",,Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserSessions" Then
		NumberOfSessions = Parameter.NumberOfSessions;
		UpdateLockState(ThisObject);
		If Parameter.Status = "Done" Then
			Close();
		ElsIf Parameter.Status = "Error" Then
			ShowMessageBox(,NStr("en='Cannot terminate sessions of all active users.
		|Look for details in event log.';ru='Не удалось завершить работу всех активных пользователей.
		|Подробности см. в журнале регистрации.'"), 30);
			Close();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ActiveUsers(Command)
	
	OpenForm("DataProcessor.ActiveUsers.Form",, ThisObject);
	
EndProcedure

&AtClient
Procedure Apply(Command)
	
	ClearMessages();
	
	Object.ProhibitUserWorkTemporarily = Not InitialUsersWorkProhibitionStatusValue;
	If Object.ProhibitUserWorkTemporarily Then
		
		NumberOfSessions = 1;
		Try
			If Not CheckBlockPreconditions() Then
				Return;
			EndIf;
		Except
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		QuestionTitle = NStr("en='User operation locking';ru='Блокировка работы пользователей'");
		If NumberOfSessions > 1 AND Object.LockBegin < CommonUseClient.SessionDate() + 5 * 60 Then
			QuestionText = NStr("en='Too early start time of blocking is set, users may not have enough time to save all their data and terminate their sessions.
		|It is recommended to set start time 5 minutes later than the current time.';ru='Указано слишком близкое время начала действия блокировки, к которому пользователи могут не успеть сохранить все свои данные и завершить работу.
		|Рекомендуется установить время начала на 5 минут относительно текущего времени.'");
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.Yes, NStr("en='Block in 5 minutes';ru='Заблокировать через 5 минут'"));
			Buttons.Add(DialogReturnCode.No, NStr("en='Lock now';ru='Заблокировать сейчас'"));
			Buttons.Add(DialogReturnCode.Cancel, NStr("en='Cancel';ru='Отменить'"));
			Notification = New NotifyDescription("ApplyEnd", ThisObject, "TooCloseLockTime");
			ShowQueryBox(Notification, QuestionText, Buttons,,, QuestionTitle);
		ElsIf Object.LockBegin > CommonUseClient.SessionDate() + 60 * 60 Then
			QuestionText = NStr("en='Stat time of blocking is too late (more than in a hour).
		|Do you want to schedule the locking for the specified time?';ru='Указано слишком большое время начала действия блокировки (более, чем через час).
		|Запланировать блокировку на указанное время?'");
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.No, NStr("en='Schedule';ru='Расписание'"));
			Buttons.Add(DialogReturnCode.Yes, NStr("en='Lock now';ru='Заблокировать сейчас'"));
			Buttons.Add(DialogReturnCode.Cancel, NStr("en='Cancel';ru='Отменить'"));
			Notification = New NotifyDescription("ApplyEnd", ThisObject, "TooMuchLockTime");
			ShowQueryBox(Notification, QuestionText, Buttons,,, QuestionTitle);
		Else
			If Object.LockBegin - CommonUseClient.SessionDate() > 15*60 Then
				QuestionText = NStr("en='Sessions of all active users will be terminated during the period from %1 to %2.
		|Continue?';ru='Завершение работы всех активных пользователей будет произведено в период с %1 по %2.
		|Продолжить?'");
			Else
				QuestionText = NStr("en='Sessions of all active users will be terminated by %2.
		|Continue?';ru='Сеансы всех активных пользователей будут завершены к %2.
		|Продолжить?'");
			EndIf;
			Notification = New NotifyDescription("ApplyEnd", ThisObject, "Confirmation");
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			QuestionText, Object.LockBegin - 900, Object.LockBegin);
			ShowQueryBox(Notification, QuestionText, QuestionDialogMode.OKCancel,,, QuestionTitle);
		EndIf;
		
	Else
		
		Notification = New NotifyDescription("ApplyEnd", ThisObject, "Confirmation");
		ExecuteNotifyProcessing(Notification, DialogReturnCode.OK);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplyEnd(Response, Variant) Export
	
	If Variant = "TooCloseLockTime" Then
		If Response = DialogReturnCode.Yes Then
			Object.LockBegin = CommonUseClient.SessionDate() + 5 * 60;
		ElsIf Response <> DialogReturnCode.No Then
			Return;
		EndIf;
	ElsIf Variant = "TooMuchLockTime" Then
		If Response = DialogReturnCode.Yes Then
			Object.LockBegin = CommonUseClient.SessionDate() + 5 * 60;
		ElsIf Response <> DialogReturnCode.No Then
			Return;
		EndIf;
	ElsIf Variant = "Confirmation" Then
		If Response <> DialogReturnCode.OK Then
			Return;
		EndIf;
	EndIf;
	
	If EnteredCorrectAdministrationParameters AND ThisIsSystemAdministrator AND Not ThisIsFileBase
		AND LockCurrentValue <> Object.DisableScheduledJobs Then
		
		Try
			
			If ClientConnectedViaWebServer Then
				SetSheduledJobLockAtServer(AdministrationParameters);
			Else
				ClusterAdministrationClientServer.LockInfobaseSheduledJobs(
					AdministrationParameters,, Object.DisableScheduledJobs);
			EndIf;
			
		Except
			EventLogMonitorClient.AddMessageForEventLogMonitor(InfobaseConnectionsClientServer.EventLogMonitorEvent(), "Error",
				DetailErrorDescription(ErrorInfo()),, True);
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
			Return;
		EndTry;
		
	EndIf;
	
	If Not ThisIsFileBase AND Not EnteredCorrectAdministrationParameters AND SessionWithoutSeparator Then
		
		NotifyDescription = New NotifyDescription("AfterAdministrationParametersGettingOnBlocking", ThisObject);
		FormTitle = NStr("en='Session lock management';ru='Управление блокировкой сеансов'");
		ExplanatoryInscription = NStr("en='For session lock management it
		|is necessary to enter administration parameters of server cluster and infobases';ru='Для управления блокировкой сеансов
		|необходимо ввести параметры администрирования кластера серверов и информационной базы'");
		InfobaseConnectionsClient.ShowAdministrationParameters(NOTifyDescription, True,
			True, AdministrationParameters, FormTitle, ExplanatoryInscription);
		
	Else
		
		AfterAdministrationParametersGettingOnBlocking(True, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Stop(Command)
	
	If Not ThisIsFileBase AND Not EnteredCorrectAdministrationParameters AND SessionWithoutSeparator Then
		
		NotifyDescription = New NotifyDescription("AfterAdministrationParametersGettingWhenLockCanceling", ThisObject);
		FormTitle = NStr("en='Session lock management';ru='Управление блокировкой сеансов'");
		ExplanatoryInscription = NStr("en='For session lock management it
		|is necessary to enter administration parameters of server cluster and infobases';ru='Для управления блокировкой сеансов
		|необходимо ввести параметры администрирования кластера серверов и информационной базы'");
		InfobaseConnectionsClient.ShowAdministrationParameters(NOTifyDescription, True,
			True, AdministrationParameters, FormTitle, ExplanatoryInscription);
		
	Else
		
		AfterAdministrationParametersGettingWhenLockCanceling(True, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdministrationParameters(Command)
	
	NotifyDescription = New NotifyDescription("AfterAdministrationParametersReceiving", ThisObject);
	FormTitle = NStr("en='Scheduled job lock management';ru='Управление блокировкой регламентных заданий'");
	ExplanatoryInscription = NStr("en='For management of scheduled jobs
		|locking it is necessary to enter administration parameters of server cluster and infobases';ru='Для управления блокировкой
		|регламентных заданий необходимо ввести параметры администрирования кластера серверов и информационной базы'");
	InfobaseConnectionsClient.ShowAdministrationParameters(NOTifyDescription, True,
		True, AdministrationParameters, FormTitle, ExplanatoryInscription);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserWorkProhibitionState.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersWorkProhibitionStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en='Prohibited';ru='Запрещено'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ExplanationTextError);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserWorkProhibitionState.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersWorkProhibitionStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en='Planned';ru='планируемый'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ExplanationTextError);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserWorkProhibitionState.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersWorkProhibitionStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en='Expired';ru='Истекло'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.BlockedAttributeColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserWorkProhibitionState.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("UsersWorkProhibitionStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en='Allowed';ru='Разрешено'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.FormTextColor);

EndProcedure

&AtServer
Function CheckBlockPreconditions()
	
	Return CheckFilling();

EndFunction

&AtServer
Function SetRemoveLock()
	
	Try
		FormAttributeToValue("Object").RunSetup();
		Items.ErrorGroup.Visible = False;
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMonitorEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If ThisIsSystemAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
		EndIf;
		Return False;
	EndTry;
	
	InstallStarterStatusBanUsers();
	NumberOfSessions = InfobaseConnections.InfobaseSessionCount();
	Return True;
	
EndFunction

&AtServer
Function Unlock()
	
	Try
		FormAttributeToValue("Object").Unlock();
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMonitorEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If ThisIsSystemAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
		EndIf;
		Return False;
	EndTry;
	InstallStarterStatusBanUsers();
	Items.ModeGroup.CurrentPage = Items.SettingsPage;
	RefreshSettingsPage();
	Return True;
	
EndFunction

&AtServer
Procedure RefreshSettingsPage()
	
	Items.DisableScheduledJobsGroup.Enabled = True;
	Items.ApplyCommand.Visible = True;
	Items.ApplyCommand.DefaultButton = True;
	Items.StopCommand.Visible = False;
	Items.ApplyCommand.Title = ?(Object.ProhibitUserWorkTemporarily,
		NStr("en='Unlock';ru='Снять блокировку'"), NStr("en='Lock';ru='Установить блокировку'"));
	Items.DisableScheduledJobs.Title = ?(Object.DisableScheduledJobs,
		NStr("en='Keep locking operations of scheduled jobs';ru='Оставить блокировку работы регламентных заданий'"), NStr("en='Also disable scheduled jobs';ru='Также запретить работу регламентных заданий'"));
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshStatePage(Form)
	
	Form.Items.DisableScheduledJobsGroup.Enabled = False;
	Form.Items.StopCommand.Visible = True;
	Form.Items.ApplyCommand.Visible = False;
	Form.Items.CloseCommand.DefaultButton = True;
	UpdateLockState(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateLockState(Form)
	
	Form.Items.Status.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Please wait...
		|User operation is terminated. Active sessions left: %1';ru='Пожалуйста, подождите..
		|Работа пользователей завершается. Осталось активных сеансов: %1'"),
			Form.NumberOfSessions);
	
EndProcedure

&AtServer
Procedure GetBlockParameters()
	DataProcessor = FormAttributeToValue("Object");
	Try
		DataProcessor.GetBlockParameters();
		Items.ErrorGroup.Visible = False;
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMonitorEvent(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If ThisIsSystemAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
		EndIf;
	EndTry;
	
	ValueToFormAttribute(DataProcessor, "Object");
	
EndProcedure

&AtServer
Function ErrorShortInfo(ErrorDescription)
	ErrorText = ErrorDescription;
	Position = Find(ErrorText, "}:");
	If Position > 0 Then
		ErrorText = TrimAll(Mid(ErrorText, Position + 2, StrLen(ErrorText)));
	EndIf;
	Return ErrorText;
EndFunction	

&AtServer
Procedure InstallStarterStatusBanUsers()
	
	InitialUsersWorkProhibitionStatusValue = Object.ProhibitUserWorkTemporarily;
	If Object.ProhibitUserWorkTemporarily Then
		If CurrentSessionDate() < Object.LockBegin Then
			InitialUserWorkProhibitionState = NStr("en='User operation in the application will be prohibited at the specified time';ru='Работа пользователей в программе будет запрещена в указанное время'");
			UsersWorkProhibitionStatus = "Planned";
		ElsIf CurrentSessionDate() > Object.LockEnding AND Object.LockEnding <> '00010101' Then
			InitialUserWorkProhibitionState = NStr("en='User operation in the application is allowed (prohibition period has ended)';ru='Работа пользователей в программе разрешена (истек срок запрета)'");;
			UsersWorkProhibitionStatus = "Timed Out";
		Else
			InitialUserWorkProhibitionState = NStr("en='User operation in the application is prohibited';ru='Работа пользователей в программе запрещена'");
			UsersWorkProhibitionStatus = "Prohibited";
		EndIf;
	Else
		InitialUserWorkProhibitionState = NStr("en='User operation in the application is allowed';ru='Работа пользователей в программе разрешена'");
		UsersWorkProhibitionStatus = "Allowed";
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAdministrationParametersReceiving(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		AdministrationParameters = Result;
		EnteredCorrectAdministrationParameters = True;
		
		Try
			If ClientConnectedViaWebServer Then
				Object.DisableScheduledJobs = InfobaseScheduledJobsLockingAtServer(AdministrationParameters);
			Else
				Object.DisableScheduledJobs = ClusterAdministrationClientServer.InfobaseScheduledJobsLocking(AdministrationParameters);
			EndIf;
			LockCurrentValue = Object.DisableScheduledJobs;
		Except;
			EnteredCorrectAdministrationParameters = False;
			Raise;
		EndTry;
		
		Items.DisableScheduledJobsGroup.CurrentPage = Items.GroupScheduledJobsManagement;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAdministrationParametersGettingOnBlocking(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf TypeOf(Result) = Type("Structure") Then
		AdministrationParameters = Result;
		EnteredCorrectAdministrationParameters = True;
		EnableScheduledJobLockManagement();
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	ElsIf TypeOf(Result) = Type("Boolean") AND EnteredCorrectAdministrationParameters Then
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	EndIf;
	
	If Not SetRemoveLock() Then
		Return;
	EndIf;
	
	ShowUserNotification(NStr("en='User operation locking';ru='Блокировка работы пользователей'"),
		"e1cib/app/DataProcessor.UserWorkBlocking",
		?(Object.ProhibitUserWorkTemporarily, NStr("en='Locked.';ru='Блокировка установлена.'"), NStr("en='Unlocked.';ru='Блокировка снята.'")),
		PictureLib.Information32);
	InfobaseConnectionsClient.SetIdleHandlerOfUserSessionsTermination(	Object.ProhibitUserWorkTemporarily);
	
	If Object.ProhibitUserWorkTemporarily Then
		RefreshStatePage(ThisObject);
	Else
		RefreshSettingsPage();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAdministrationParametersGettingWhenLockCanceling(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf TypeOf(Result) = Type("Structure") Then
		AdministrationParameters = Result;
		EnteredCorrectAdministrationParameters = True;
		EnableScheduledJobLockManagement();
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	ElsIf TypeOf(Result) = Type("Boolean") AND EnteredCorrectAdministrationParameters Then
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	EndIf;
	
	If Not Unlock() Then
		Return;
	EndIf;
	
	InfobaseConnectionsClient.SetIdleHandlerOfUserSessionsTermination(False);
	ShowMessageBox(,NStr("en='Termination of active user sessions has been canceled. 
		|New users can not log on to the application.';ru='Завершение работы активных пользователей отменено. 
		|Вход в программу новых пользователей оставлен заблокированным.'"));
	
EndProcedure

&AtClient
Procedure EnableScheduledJobLockManagement()
	
	If ClientConnectedViaWebServer Then
		Object.DisableScheduledJobs = InfobaseScheduledJobsLockingAtServer(AdministrationParameters);
	Else
		Object.DisableScheduledJobs = ClusterAdministrationClientServer.InfobaseScheduledJobsLocking(AdministrationParameters);
	EndIf;
	LockCurrentValue = Object.DisableScheduledJobs;
	Items.DisableScheduledJobsGroup.CurrentPage = Items.GroupScheduledJobsManagement;
	
EndProcedure

&AtServer
Procedure SetSheduledJobLockAtServer(AdministrationParameters)
	
	ClusterAdministrationClientServer.LockInfobaseSheduledJobs(
		AdministrationParameters,, Object.DisableScheduledJobs);
	
EndProcedure
	
&AtServer
Function InfobaseScheduledJobsLockingAtServer(AdministrationParameters)
	
	Return ClusterAdministrationClientServer.InfobaseScheduledJobsLocking(AdministrationParameters);
	
EndFunction

#EndRegion