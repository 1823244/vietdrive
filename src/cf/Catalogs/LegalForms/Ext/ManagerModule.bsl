#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region ServiceProceduresAndFunctions

Procedure FillAvailableLegalForms() Export

	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	LegalForms.Ref AS LegalForm
		|FROM
		|	Catalog.LegalForms AS LegalForms";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	// 1. LLC
	LegalForm = Catalogs.LegalForms.CreateItem();
	LegalForm.Description	= NStr("en = 'Limited Liability Company'; ru = 'Общество с ограниченной ответственностью'");
	LegalForm.ShortName		= NStr("en = 'LLC'; ru = 'ООО'");
	
	InfobaseUpdate.WriteData(LegalForm);
	
	// 2. FZE
	LegalForm = Catalogs.LegalForms.CreateItem();
	LegalForm.Description	= NStr("en = 'Free Zone Establishment'; ru = 'Непубличное акционерное общество'");
	LegalForm.ShortName		= NStr("en = 'FZE'; ru = 'АО'");
	
	InfobaseUpdate.WriteData(LegalForm);
	
	// 3. FZCO
	LegalForm = Catalogs.LegalForms.CreateItem();
	LegalForm.Description	= NStr("en = 'Free Zone Company'; ru = 'Публичное акционерное общество'");
	LegalForm.ShortName		= NStr("en = 'FZCO'; ru = 'ПАО'");
	
	InfobaseUpdate.WriteData(LegalForm);

EndProcedure

#EndRegion

#EndIf