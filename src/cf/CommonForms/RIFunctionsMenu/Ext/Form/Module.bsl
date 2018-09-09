
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FOMultipleCompaniesAccounting = GetFunctionalOption("UseSeveralCompanies");
	Items.LabelCompany.Title = ?(FOMultipleCompaniesAccounting, NStr("en = 'Companies'; ru = 'Организации'"), NStr("en = 'Company'; ru = 'Организация'"));
	
	FOAccountingBySeveralWarehouses = GetFunctionalOption("AccountingBySeveralWarehouses");
	Items.LabelWarehouses.Title = ?(FOAccountingBySeveralWarehouses, NStr("en = 'Warehouses'; ru = 'Склады'"), NStr("en = 'Warehouse'; ru = 'Склад'"));
	
	FOAccountingBySeveralDepartments = GetFunctionalOption("AccountingBySeveralDepartments");
	Items.LabelDepartments.Title = ?(FOAccountingBySeveralDepartments, NStr("en = 'Departments'; ru = 'Подразделения'"), NStr("en = 'Department'; ru = 'Подразделение'"));
	
	FOAccountingBySeveralBusinessActivities = GetFunctionalOption("AccountingBySeveralBusinessActivities");
	Items.LabelBusinessActivities.Title = ?(FOAccountingBySeveralBusinessActivities, NStr("en = 'Business activities'; ru = 'Направления деятельности'"), NStr("en = 'Business activity'; ru = 'Направление деятельности'"));
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet" Then 
		
		If Source = "UseSeveralCompanies" Then
			
			FOMultipleCompaniesAccounting = GetFOServer("UseSeveralCompanies");
			Items.LabelCompany.Title = ?(FOMultipleCompaniesAccounting, NStr("en = 'Companies'; ru = 'Организации'"), NStr("en = 'Company'; ru = 'Организация'"));
			
		ElsIf Source = "FunctionalOptionAccountingByMultipleWarehouses" Then
			
			FOAccountingBySeveralWarehouses = GetFOServer("AccountingBySeveralWarehouses");
			Items.LabelWarehouses.Title = ?(FOAccountingBySeveralWarehouses, NStr("en = 'Warehouses'; ru = 'Склады'"), NStr("en = 'Warehouse'; ru = 'Склад'"));
			
		ElsIf Source = "FunctionalOptionAccountingByMultipleDepartments" Then
			
			FOAccountingBySeveralDepartments = GetFOServer("AccountingBySeveralDepartments");
			Items.LabelDepartments.Title = ?(FOAccountingBySeveralDepartments, NStr("en = 'Departments'; ru = 'Подразделения'"), NStr("en = 'Department'; ru = 'Подразделение'"));
			
		ElsIf Source = "FunctionalOptionAccountingByMultipleBusinessActivities" Then
			
			FOAccountingBySeveralBusinessActivities = GetFOServer("AccountingBySeveralBusinessActivities");
			Items.LabelBusinessActivities.Title = ?(FOAccountingBySeveralBusinessActivities, NStr("en = 'Business activities'; ru = 'Направления деятельности'"), NStr("en = 'Business activity'; ru = 'Направление деятельности'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure LabelCompaniesClick(Item)
	
	If FOMultipleCompaniesAccounting Then
		OpenForm("Catalog.Companies.ListForm");
	Else
		ParemeterCompany = New Structure("Key", PredefinedValue("Catalog.Companies.MainCompany"));
		OpenForm("Catalog.Companies.ObjectForm", ParemeterCompany);
	EndIf;
	
EndProcedure // LabelCompaniesClick()

// Procedure - command handler CatalogWarehouses.
//
&AtClient
Procedure LableWarehousesClick(Item)
	
	If FOAccountingBySeveralWarehouses Then
		
		FilterArray = New Array;
		FilterArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.Warehouse"));
		FilterArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.Retail"));
		FilterArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.RetailAccrualAccounting"));
		
		FilterStructure = New Structure("StructuralUnitType", FilterArray);
		
		OpenForm("Catalog.StructuralUnits.ListForm", New Structure("Filter", FilterStructure));
		
	Else
		
		ParameterWarehouse = New Structure("Key", PredefinedValue("Catalog.StructuralUnits.MainWarehouse"));
		OpenForm("Catalog.StructuralUnits.ObjectForm", ParameterWarehouse);
		
	EndIf;
	
EndProcedure // LableWarehousesClick()

// Procedure - command handler CatalogDepartments.
//
&AtClient
Procedure LabelDepartmentClick(Item)
	
	If FOAccountingBySeveralDepartments Then
		
		FilterStructure = New Structure("StructuralUnitType", PredefinedValue("Enum.StructuralUnitsTypes.Department"));
		
		OpenForm("Catalog.StructuralUnits.ListForm", New Structure("Filter", FilterStructure));
	
	Else
		
		ParameterDepartment = New Structure("Key", PredefinedValue("Catalog.StructuralUnits.MainDepartment"));
		OpenForm("Catalog.StructuralUnits.ObjectForm", ParameterDepartment);
		
	EndIf;
	
EndProcedure // LabelDepartmentClick()

// Procedure - command handler CatalogBusinessActivities.
//
&AtClient
Procedure LableBusinessActivitiesClick(Item)
	
	If FOAccountingBySeveralBusinessActivities Then
		OpenForm("Catalog.BusinessActivities.ListForm");
	Else
		
		ParameterBusinessActivity = New Structure("Key", PredefinedValue("Catalog.BusinessActivities.MainActivity"));
		OpenForm("Catalog.BusinessActivities.ObjectForm", ParameterBusinessActivity);
		
	EndIf;
	
EndProcedure // LableBusinessActivitiesClick()

#Region ServiceProceduresAndFunctions
	
&AtServerNoContext
Function GetFOServer(NameFunctionalOption)
	
	Return GetFunctionalOption(NameFunctionalOption);
	
EndFunction

#EndRegion