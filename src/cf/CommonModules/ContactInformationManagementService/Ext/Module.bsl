////////////////////////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Returns enumeration value type of the contact information kind.
//
//  Parameters:
//    InformationKind - CatalogRef.ContactInformationTypes, Structure - data source.
//
Function TypeKindContactInformation(Val InformationKind) Export
	Result = Undefined;
	
	Type = TypeOf(InformationKind);
	If Type = Type("EnumRef.ContactInformationTypes") Then
		Result = InformationKind;
	ElsIf Type = Type("CatalogRef.ContactInformationKinds") Then
		Result = InformationKind.Type;
	ElsIf InformationKind <> Undefined Then
		Data = New Structure("Type");
		FillPropertyValues(Data, InformationKind);
		Result = Data.Type;
	EndIf;
	
	Return Result;
EndFunction

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  Handlers - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to countries classifier is denied.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.WorldCountries.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure

// Define metadata objects in the managers modules of which
// the ability to edit attributes is restricted using the GetLockedOjectAttributes export function.
//
// Parameters:
//   Objects - Map - specify the full name of the metadata
//                            object as a key connected to the Deny editing objects attributes subsystem. 
//                            As a value - empty row.
//
Procedure OnDetermineObjectsWithLockedAttributes(Objects) Export
	
	Objects.Insert(Metadata.Catalogs.ContactInformationKinds.FullName(), "");
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ContactInformationKinds.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region InfobaseUpdate

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable
//                                  function description of InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
		
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctionsForCompatibility

// Parameters: Owner - XDTOObject, Undefined
//
Function HasFilledPropertiesXDTOContactInformation(Val Owner)
	
	If Owner = Undefined Then
		Return False;
	EndIf;
	
	// List of the ignored on comparing properties of the current owner - specifications of contact information.
	Ignored = New Map;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	OwnerType     = Owner.Type();
	
	If OwnerType = XDTOFactory.Type(TargetNamespace, "Address") Then
		// Country does not affect the filling in if the remainings are empty. Ignore.
		Ignored.Insert(Owner.Properties().Get("Country"), True);
		
	ElsIf OwnerType = XDTOFactory.Type(TargetNamespace, "AddressRF") Then
		// Ignore list with empty values and possibly not empty types.
		List = Owner.GetList("AddEMailAddress");
		If List <> Undefined Then
			For Each ListProperty In List Do
				If IsBlankString(ListProperty.Value) Then
					Ignored.Insert(ListProperty, True);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	For Each Property In Owner.Properties() Do
		
		If Not Owner.IsSet(Property) Or Ignored[Property] <> Undefined Then
			Continue;
		EndIf;
		
		If Property.UpperBound > 1 Or Property.UpperBound < 0 Then
			List = Owner.GetList(Property);
			
			If List <> Undefined Then
				For Each ItemOfList In List Do
					If Ignored[ItemOfList] = Undefined 
						AND HasFilledPropertiesXDTOContactInformation(ItemOfList) 
					Then
						Return True;
					EndIf;
				EndDo;
			EndIf;
			
			Continue;
		EndIf;
		
		Value = Owner.Get(Property);
		If TypeOf(Value) = Type("XDTODataObject") Then
			If HasFilledPropertiesXDTOContactInformation(Value) Then
				Return True;
			EndIf;
			
		ElsIf Not IsBlankString(Value) Then
			Return True;
			
		EndIf;
		
	EndDo;
		
	Return False;
EndFunction

#EndRegion

#EndRegion
