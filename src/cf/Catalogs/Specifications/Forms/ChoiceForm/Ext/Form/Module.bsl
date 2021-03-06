﻿

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			OwnerType = Parameters.Filter.Owner.ProductsAndServicesType;
			
			If (OwnerType = Enums.ProductsAndServicesTypes.Operation
				OR OwnerType = Enums.ProductsAndServicesTypes.WorkKind
				OR OwnerType = Enums.ProductsAndServicesTypes.Service
				OR (NOT Constants.FunctionalOptionUseSubsystemProduction.Get() AND OwnerType = Enums.ProductsAndServicesTypes.InventoryItem)
				OR (NOT Constants.FunctionalOptionUseWorkSubsystem.Get() AND OwnerType = Enums.ProductsAndServicesTypes.Work)) Then
			
				Message = New UserMessage();
				LabelText = NStr("en='BOM is not specified for products and services of the %EtcProductsAndServices% type.';
								 |ru='Для номенклатуры типа %EtcProductsAndServices% спецификация не указывается!'");
				LabelText = StrReplace(LabelText, "%EtcProductsAndServices%", OwnerType);
				Message.Text = LabelText;
				Message.Message();
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure