#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>


#define PLUGIN_VERSION 		"1.0"
#define PLUGIN_NAME 		"sakaCHATCPU"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Manipulate Chat"
#define PLUGIN_URL 			"https://tf2.l03.dev/"

#define SENDER_WORLD        0
#define MAXLENGTH_INPUT     128
#define MAXLENGTH_NAME      64
#define MAXLENGTH_MESSAGE   256
#define CHATFLAGS_INVALID   0
#define CHATFLAGS_ALL       (1 << 0)
#define CHATFLAGS_TEAM      (1 << 1)
#define CHATFLAGS_SPEC      (1 << 2)
#define CHATFLAGS_DEAD      (1 << 3)
#define ADDSTRING(%1)       SetTrieValue(hChatFormats, %1, 1)

public Plugin myinfo =  {
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

Handle hChatFormats = INVALID_HANDLE;
Handle hFwdOnChatMessage;
Handle hFwdOnChatMessagePost;
Handle hDPArray = INVALID_HANDLE;
bool bSayText2;
int iCurrentChatType = CHATFLAGS_INVALID;
enum Game {
    GameType_TF
} 
Game gGameType = GameType_TF;



public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    MarkNativeAsOptional("GetUserMessageType");
    CreateNative("GetMessageFlags", Native_GetMessageFlags);
    RegPluginLibrary("sakacp");
    return APLRes_Success;
} 



public void OnPluginStart() {
    hChatFormats = CreateTrie();

    UserMsg umSayText2 = GetUserMessageId("SayText2");
    if (umSayText2 != INVALID_MESSAGE_ID) {
        bSayText2 = true;
        HookUserMessage(umSayText2, OnSayText2, true);
    } 
    if (bSayText2) {
        LoadTranslations("sakachatcpu.phrases.txt");
    }
    hFwdOnChatMessage = CreateGlobalForward("OnChatMessage", ET_Hook, Param_CellByRef, Param_Cell, Param_String, Param_String);
    hFwdOnChatMessagePost = CreateGlobalForward("OnChatMessage_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
    hDPArray = CreateArray();
}




public Action OnSayText2(UserMsg umMsgId, Handle hBf, const int[] iClients, int iNumClients, bool bReliable, bool bInit) {
    bool bProtoBuf = (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf);
    int iCpSender;
    if (bProtoBuf) iCpSender = PbReadInt(hBf, "ent_idx");
    else iCpSender = BfReadByte(hBf);
    
    if (iCpSender == SENDER_WORLD)return Plugin_Continue;
    
    bool bChat;
    if (bProtoBuf) bChat = PbReadBool(hBf, "chat");
    else bChat = (BfReadByte(hBf) ? true : false);

    char sCpTranslationName[32];
    any aBuffer;

    if (bProtoBuf) PbReadString(hBf, "msg_name", sCpTranslationName, sizeof(sCpTranslationName));
    else BfReadString(hBf, sCpTranslationName, sizeof(sCpTranslationName));
    
    if (!GetTrieValue(hChatFormats, sCpTranslationName, aBuffer)) return Plugin_Continue;
    else {
        if (StrContains(sCpTranslationName, "all", false) != -1) {
            iCurrentChatType = iCurrentChatType | CHATFLAGS_ALL;
        }
        if (StrContains(sCpTranslationName, "team", false) != -1
		|| 	StrContains(sCpTranslationName, "survivor", false) != -1 
		||	StrContains(sCpTranslationName, "infected", false) != -1
		||	StrContains(sCpTranslationName, "Cstrike_Chat_CT", false) != -1 
		||	StrContains(sCpTranslationName, "Cstrike_Chat_T", false) != -1) {
            iCurrentChatType = iCurrentChatType | CHATFLAGS_TEAM;
        }
        if (StrContains(sCpTranslationName, "spec", false) != -1) {
            iCurrentChatType = iCurrentChatType | CHATFLAGS_SPEC;
        }
        if (StrContains(sCpTranslationName, "dead", false) != -1) {
            iCurrentChatType = iCurrentChatType | CHATFLAGS_DEAD;
        }
    }
    /**
     * Get the Senders Name
     */

    char sCpSenderName[MAXLENGTH_NAME];
    if (bProtoBuf) PbReadString(hBf, "params", sCpSenderName, sizeof(sCpSenderName), 0);
    else if (BfGetNumBytesLeft(hBf)) BfReadString(hBf, sCpSenderName, sizeof(sCpSenderName));
    
    /**
     * Get the Message
     */
    char sCpMessage[MAXLENGTH_INPUT];
    if (bProtoBuf) PbReadString(hBf, "params", sCpMessage, sizeof(sCpMessage));
    else if (BfGetNumBytesLeft(hBf)) BfReadString(hBf, sCpMessage, sizeof(sCpMessage));
    
    /**
     * Store the clients in an Array, so the Call can manipulate it.
     */
    Handle hCpRecipients = CreateArray();
    for (int i = 0; i < iNumClients; i++) {
        PushArrayCell(hCpRecipients, iClients[i]);
    }
    /**
	Because the message could be changed but not the name
	we need to compare the original name to the returned name.
	We do this because we may have to add the team color code to the name,
	where as the message doesn't get a color code by default.
	*/
    char sOriginalName[MAXLENGTH_NAME];
    strcopy(sOriginalName, sizeof(sOriginalName), sCpSenderName);

    /**
	Start the forward for other plugins
	*/
    Action aResult;
    Call_StartForward(hFwdOnChatMessage);
    Call_PushCellRef(iCpSender);
    Call_PushCell(hCpRecipients);
    Call_PushStringEx(sCpSenderName, sizeof(sCpSenderName), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushStringEx(sCpMessage, sizeof(sCpMessage), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    int aError = Call_Finish(aResult);
    int iChatFlags = iCurrentChatType;
    iCurrentChatType = CHATFLAGS_INVALID;

    if (aError != SP_ERROR_NONE) {
        ThrowNativeError(aError, "Forward failed");
        CloseHandle(hCpRecipients);
        return Plugin_Continue;
    } else if (aResult == Plugin_Continue) {
        CloseHandle(hCpRecipients);
        return Plugin_Continue;
    } else if (aResult == Plugin_Stop) {
        CloseHandle(hCpRecipients);
        return Plugin_Handled;
    }

    /**
     * This is the check for a name change. If it hasn't been changed, we add the team color code
     */
    if (StrEqual(sOriginalName, sCpSenderName)) {
        Format(sCpSenderName, sizeof(sCpSenderName), "\x03%s", sCpSenderName);
    }

    /**
     * Create a Timer to print the message on the next gameframe
     */
    Handle hCpPack = CreateDataPack();
    int iNumRecipients = GetArraySize(hCpRecipients);

    WritePackCell(hCpPack, iCpSender);
    for (int i = 0; i < iNumRecipients; i++) {
        int x = GetArrayCell(hCpRecipients, i);
        if (!IsValidClient(x)) {
            iNumRecipients --;
            RemoveFromArray(hCpRecipients, i);
        }
    }

    WritePackCell(hCpPack, iNumRecipients);
    for (int i = 0; i < iNumRecipients; i++) {
        int x = GetArrayCell(hCpRecipients, i);
        WritePackCell(hCpPack, x);
    } 

    WritePackCell(hCpPack, bChat);
    WritePackString(hCpPack, sCpTranslationName);
    WritePackString(hCpPack, sCpSenderName);
    WritePackString(hCpPack, sCpMessage);
    PushArrayCell(hDPArray, hCpPack);
    WritePackCell(hCpPack, bProtoBuf);
    WritePackCell(hCpPack, iChatFlags);
    CloseHandle(hCpRecipients);
    /**
     * Stop the original message
     */
    return Plugin_Handled;
}

public void OnGameFrame() {
    for (int i = 0; i < GetArraySize(hDPArray); i++) {
        Handle hPack = GetArrayCell(hDPArray, i);
        ResetPack(hPack);
        char sSenderName[MAXLENGTH_NAME], sMessage[MAXLENGTH_INPUT];
        int iClient;
        Handle hRecipients = CreateArray();
        if (bSayText2) {
            iClient = ReadPackCell(hPack);
            int iNumClientsStart = ReadPackCell(hPack);
            int iNumClientsFinish;
            int iClients[MAXPLAYERS];
            for (int x = 0; x < iNumClientsStart; x++) {
                int iBuffer = ReadPackCell(hPack);
                if (IsValidClient(iBuffer)) {
                    iClients[iNumClientsFinish++] = iBuffer;
                    PushArrayCell(hRecipients, iBuffer);
                }
            }
            bool bChat = ReadPackCell(hPack);
            char sChatType[32];
            ReadPackString(hPack, sChatType, sizeof(sChatType));
            ReadPackString(hPack, sSenderName, sizeof(sSenderName));
            ReadPackString(hPack, sMessage, sizeof(sMessage));

            char sTranslation[MAXLENGTH_MESSAGE];
            Format(sTranslation, sizeof(sTranslation), "%t", sChatType, sSenderName, sMessage);
            Handle hBf = StartMessage("SayText2", iClients, iNumClientsFinish, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);

            if (ReadPackCell(hPack)) {
                PbSetInt(hBf, "ent_idx", iClient);
                PbSetBool(hBf, "chat", bChat);
                PbSetString(hBf, "msg_name", sTranslation);
                PbAddString(hBf, "params", "");
                PbAddString(hBf, "params", "");
                PbAddString(hBf, "params", "");
                PbAddString(hBf, "params", "");
            } else {
                BfWriteByte(hBf, iClient);
                BfWriteByte(hBf, bChat);
                BfWriteString(hBf, sTranslation);
            }
            EndMessage();
        } else {
            iClient = ReadPackCell(hPack);
            int iNumClientsStart = ReadPackCell(hPack);
            int iNumClientsFinish;
            int iClients[64];
            for (int x = 0; i < iNumClientsStart; x++) {
                int iBuffer = ReadPackCell(hPack);
                if (IsValidClient(iBuffer)) {
                    iClients[iNumClientsFinish++] = iBuffer;
                    PushArrayCell(hRecipients, iBuffer);
                }
            }

            char sPrefix[MAXLENGTH_NAME];
            ReadPackString(hPack, sPrefix, sizeof(sPrefix));
            ReadPackString(hPack, sSenderName, sizeof(sSenderName));
            ReadPackString(hPack, sMessage, sizeof(sMessage));

            char sSecondMessage[MAXLENGTH_MESSAGE];
            int iTeamColor;
            switch (GetClientTeam(iClient)) {
                case 0, 1: iTeamColor = 0xCCCCCC;
                case 2: iTeamColor = 0x4D7942;
                case 3: iTeamColor = 0xFF4040;
            }
            char sBuffer[32];
            Format(sBuffer, sizeof(sBuffer), "\x07%06X", iTeamColor);
            ReplaceString(sSenderName, sizeof(sSenderName), "\x03", sBuffer);
            ReplaceString(sMessage, sizeof(sMessage), "\x03", sBuffer);
            Format(sSecondMessage, sizeof(sSecondMessage), "\x01%s%s\x01: %s", sPrefix, sSenderName, sMessage);
            PrintToServer(sSecondMessage);
            for (int j = 0; j < iNumClientsFinish; j++) {
                PrintToChat(iClients[j], "%s", sSecondMessage);
            }
        }
        iCurrentChatType = ReadPackCell(hPack);
        Call_StartForward(hFwdOnChatMessagePost);
        Call_PushCell(iClient);
        Call_PushCell(hRecipients);
        Call_PushString(sSenderName);
        Call_PushString(sMessage);
        Call_Finish();
        iCurrentChatType = CHATFLAGS_INVALID;
        CloseHandle(hRecipients);
        CloseHandle(hPack);
        RemoveFromArray(hDPArray, i);
    }
}

public int Native_GetMessageFlags(Handle hPlugin, int numParams) {
    return iCurrentChatType;
}

stock bool IsValidClient(int iClient, bool bNoBots = true)  {  
	if (iClient <= 0 || iClient > MaxClients || !IsClientConnected(iClient) || (bNoBots && IsFakeClient(iClient))) {  
			return false;  
	}  
	return IsClientInGame(iClient);  
}

stock bool GetChatFormats(char[] sFile) {
    Handle hParser = SMC_CreateParser();
    char sError[128];
    int iLine = 0;
    int iCol = 0;
    SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
    SMC_SetParseEnd(hParser, Config_End);
    SMCError result = SMC_ParseFile(hParser, sFile, iLine, iCol);
    if (result != SMCError_Okay) {
        SMC_GetErrorString(result, sError, sizeof(sError));
        LogError("%s on line %d, col %d of %s", sError, iLine, iCol, sFile);
    }
    return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(Handle hParser, char[] sSection, bool bQuotes) {
	if (StrEqual(sSection, "Phrases"))
	{
		return SMCParse_Continue;
	}
	ADDSTRING(sSection);
	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle hParser, char[] sKey, char[] sValue, bool bKeyQuotes, bool bValueQuotes) {
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle hParser) {
	return SMCParse_Continue;
}

public void Config_End(Handle hParser, bool bHalted, bool bFailed) {
	//nothing
}