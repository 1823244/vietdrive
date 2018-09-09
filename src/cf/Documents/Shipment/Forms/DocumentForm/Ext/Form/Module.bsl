&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.GroupImportantCommandsShipment);
	// End StandardSubsystems.Printing

	MapImg = GetURL(Object.Ref, "DestMap");
	
EndProcedure




&AtClient
Procedure GetMap(Command)

	
	
	coords = GetCoordsByAddress( Object.Address );
	
	// after that we will got 2-strings array with coordinates
	coordFields=StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(coords, " ", true, true);
	
	MapServer = "static-maps.yandex.ru/1.x/?l=map&lang=en_US&";
	
	// center of the map
	MapServer = MapServer + "ll="+coordFields[0]+","+coordFields[1]+"&";
	
	// map size
	MapServer = MapServer + "spn=0.01,0.01&";
	
	// zoom
	MapServer = MapServer + "z=13&";
	
	// point on map (destination address)
	MapServer = MapServer + "pt="+coordFields[0]+","+coordFields[1]+",pmdom1";
	
	//message(MapServer);
	
	ssl = New OpenSSLSecureConnection();
	Conn = New HTTPConnection(MapServer,,,,,,ssl);
	
	//create request
	Headers = Undefined;
	QueryBody="";
	Query = HTTPQuery("", Headers, QueryBody);
	
	
	
	Result = Conn.Get(Query, Result);
	img = Result.GetBodyAsBinaryData();
	
	//СсылкаНаКартинку = ПолучитьНавигационнуюСсылку(Объект.Ссылка, "ДанныеКартинки"); 
	MapImg = PutToTempStorage(img, UUID);
	
	items.MapImg.Visible = true;
	items.MapImg.Height = 10;
	
	// switch to MAP page
	Items.Pages.CurrentPage = Items.pages.ChildItems.MapPage;
	
	SaveMapPicture();
	
EndProcedure

// returns coordinates of address
&AtClient
Function GetCoordsByAddr(Command)
	// create connection
	// we dont need to write 'https:// ' because this will be passed through 'ssl' parameter
	//MapServer = "geocode-maps.yandex.ru/1.x/?format=json&lang=en_US&geocode=hanoi+trang%20thi+8";
	
	AddressByString = Object.Address;
	
	Return GetCoordsByAddress( AddressByString );
	
EndFunction

// returns coordinates of address
&AtClient
Function GetCoordsByAddress( AddressByString )
	// create connection
	// we dont need to write 'https:// ' because this will be passed through 'ssl' parameter
	MapServer = "geocode-maps.yandex.ru/1.x/?format=json&lang=en_US&geocode="+AddressByString;
	ssl = New OpenSSLSecureConnection();
	Conn = New HTTPConnection(MapServer,,,,,,ssl);
	//create request
	Headers = Undefined;
	QueryBody="";
	Query = HTTPQuery("", Headers, QueryBody);
	// get results
	Result = Undefined;
	Result=Conn.Get(Query);   //Result - json
	JSON = New JSONReader;
	JSON.SetString(Result.GetBodyAsString());
	w = ReadJSON(JSON);//struct
	//message(w);
	Try
		res=w.response.GeoObjectCollection.featureMember[0].GeoObject.Point.pos;//"105.850583 21.026303"
	
	Except
	    raise NStr("en='Error while retrieving coordinates of address!';ru='Ошибка получения координат по адресу!'");
	EndTry;
	return res;
	
	
EndFunction

&AtClientAtServerNoContext
Function HTTPQuery(Service, Headers = Undefined, QueryBody = Undefined)
	
	If NOT ValueIsFilled(Headers) OR ТипЗнч(Headers) <> Type("Map") Then
		Headers = New Map;
	EndIf;
	
	HTTPQuery = New HTTPRequest(Service, Headers);
	
	If ValueIsFilled(QueryBody) Then
		HTTPQuery.SetBodyFromString(QueryBody);
	EndIf;
	
	return HTTPQuery;
	
EndFunction


&AtClient
Procedure OnOpen(Cancel)
	//items.MapImg.Visible = false;
EndProcedure


&AtClient
Procedure SaveMapPicture()
	
	BinData = GetFromTempStorage(MapImg);
	
EndProcedure


&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	If IsTempStorageURL(MapImg)  Then
	
		BinData = GetFromTempStorage(MapImg);
		
		CurrentObject.DestMap = New ValueStorage(BinData, New Deflation(9));
	
	EndIf;
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	//MapImg = GetURL(CurrentObject.Ref, "DestMap");
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	// Insert handler content.
EndProcedure

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing
