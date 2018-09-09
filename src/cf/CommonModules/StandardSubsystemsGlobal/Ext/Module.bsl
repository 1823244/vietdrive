////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Continues to complete in the mode
// of interaction with user after configuring Cancel = True.
//
Procedure WaitHandlerInteractiveProcessingBeforeExit() Export
	
	StandardSubsystemsClient.StartInteractiveProcessingBeforeExit();
	
EndProcedure

// Continues to launch in the mode of interaction with user.
Procedure WaitAtSystemStartHandler() Export
	
	StandardSubsystemsClient.OnStart(, False);
	
EndProcedure

#EndRegion
