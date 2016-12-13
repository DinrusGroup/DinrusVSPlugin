// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module visuald.completion;

import visuald.windows;
import std.ascii;
import std.string;
import std.utf;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;

import stdext.array;
import stdext.file;
import stdext.ddocmacros;

import visuald.comutil;
import visuald.logutil;
import visuald.hierutil;
import visuald.fileutil;
import visuald.pkgutil;
import visuald.stringutil;
import visuald.dpackage;
import visuald.dproject;
import visuald.dlangsvc;
import visuald.dimagelist;
import visuald.dllmain;
import visuald.config;
import visuald.intellisense;

import vdc.lexer;

import sdk.port.vsi;
import sdk.win32.commctrl;
import sdk.vsi.textmgr;
import sdk.vsi.textmgr2;
import sdk.vsi.vsshell;

///////////////////////////////////////////////////////////////

const int kCompletionSearchLines = 5000;

class ImageList {};

struct Declaration
{
}

class Declarations
{
	string[] mNames;
	string[] mDescriptions;
	int[] mGlyphs;
	int mExpansionState = kStateInit;
	
	enum
	{
		kStateInit,
		kStateImport,
		kStateSemantic,
		kStateNearBy,
		kStateSymbols,
		kStateCaseInsensitive
	}
			
	this()
	{
	}

	int GetCount()
	{
		return mNames.length;
	}

	dchar OnAutoComplete(IVsTextView textView, string committedWord, dchar commitChar, int commitIndex)
	{ 
		return 0;
	}

	bool splitName(int index, string* pname, string* ptext, string* ptype, string* pdesc)
	{
		if(index < 0 || index >= mNames.length)
			return false;
		string s = mNames[index];
		auto pos1 = indexOf(s, ':');
		string name, text, type, desc;
		if(pos1 >= 0)
		{
			name = s[0 .. pos1];
			auto pos2 = indexOf(s[pos1 + 1 .. $], ':');
			if(pos2 >= 0)
			{
				type = s[pos1 + 1 .. pos1 + 1 + pos2];
				desc = s[pos1 + 1 + pos2 + 1 .. $];
			}
			else
				type = s[pos1 + 1 .. $];
		}
		else
			name = s;

		auto pos3 = indexOf(name, "|");
		if(pos3 >= 0)
		{
			text = name[pos3 + 1 .. $];
			name = name[0 .. pos3];
		}
		else
			text = name;

		if(pname)
			*pname = name;
		if(ptext)
			*ptext = text;
		if(ptype)
			*ptype = type;
		if(pdesc)
			*pdesc = desc;
		return true;
	}

	int GetGlyph(int index)
	{
		version(none)
		{
			if(index < 0 || index >= mGlyphs.length)
				return 0;
			return mGlyphs[index];
		}
		else
		{
			string type;
			if(!splitName(index, null, null, &type, null))
				return CSIMG_DMODULE;

			switch(type)
			{
				case "KW":   return CSIMG_KEYWORD;
				case "PROP": return CSIMG_PROPERTY;
				case "TEXT": return 3;
				case "MOD":  return CSIMG_DMODULE;
				case "DIR":  return CSIMG_DFOLDER;
				case "PKG":  return CSIMG_PACKAGE;
				case "MTHD": return CSIMG_MEMBER;
				case "STRU": return CSIMG_STRUCT;
				case "UNIO": return CSIMG_UNION;
				case "CLSS": return CSIMG_CLASS;
				case "IFAC": return CSIMG_INTERFACE;
				case "TMPL": return CSIMG_TEMPLATE;
				case "ENUM": return CSIMG_ENUM;
				case "EVAL": return CSIMG_ENUMMEMBER;
				case "NMIX": return CSIMG_UNKNOWN2;
				case "VAR":  return CSIMG_FIELD;
				case "OVR":  return CSIMG_UNKNOWN3;
				case "ICN":  return CSIMG_UNKNOWN3;
				default:     return 0;
			}
		}
	}
	string GetDisplayText(int index)
	{
		return GetName(index);
	}
	string GetDescription(int index)
	{
		version(none)
		{
			if(index < 0 || index >= mDescriptions.length)
				return "";
			return mDescriptions[index];
		}
		else
		{
			string desc;
			splitName(index, null, null, null, &desc);
			desc = replace(desc, "\a", "\n");
			
			string res = phobosDdocExpand(desc);

			return res;
		}
	}
	string GetName(int index)
	{
		string name;
		splitName(index, &name, null, null, null);
		return name;
	}

	string GetText(IVsTextView view, int index)
	{
		string text;
		splitName(index, null, &text, null, null);
		if(text.indexOf('\a') >= 0)
		{
			string nl = "\r\n";
			if(view)
			{
				// copy indentation from current line
				int line, idx;
				if(view.GetCaretPos(&line, &idx) == S_OK)
				{
					IVsTextLines pBuffer;
					if(view.GetBuffer(&pBuffer) == S_OK)
					{
						LINEDATA lineData;
						if(pBuffer.GetLineData(line, &lineData, null) == S_OK)
						{
							switch(lineData.iEolType)
							{
								default:
								case eolCRLF: nl = "\r\n"; break;
								case eolCR: nl = "\r"; break;
								case eolLF: nl = "\n"; break;
							}
							pBuffer.ReleaseLineData(&lineData);
						}

						BSTR btext;
						if(pBuffer.GetLineText(line, 0, line, idx, &btext) == S_OK)
						{
							string txt = detachBSTR(btext);
							size_t p = 0;
							while(p < txt.length && isWhite(txt[p]))
								p++;
							nl ~= txt[0 .. p];
						}
						release(pBuffer);
					}
				}
			}
			text = text.replace("\a", nl);
		}
		return text;
	}

	bool GetInitialExtent(IVsTextView textView, int* line, int* startIdx, int* endIdx)
	{
		*line = 0;
		*startIdx = *endIdx = 0;
		return false;
	}
	void GetBestMatch(string textSoFar, int* index, bool *uniqueMatch)
	{
		*index = 0;
		*uniqueMatch = false;
	}
	bool IsCommitChar(string textSoFar, int index, dchar ch)
	{
		return ch == '\n' || ch == '\r'; // !(isAlphaNum(ch) || ch == '_');
	}
	string OnCommit(IVsTextView textView, string textSoFar, dchar ch, int index, ref TextSpan initialExtent)
	{
		return GetText(textView, index); // textSoFar;
	}

	///////////////////////////////////////////////////////////////
	bool ImportExpansions(string imp, string file)
	{
		string[] imports = GetImportPaths(file);
		
		string dir;
		int dpos = lastIndexOf(imp, '.');
		if(dpos >= 0)
		{
			dir = replace(imp[0 .. dpos], ".", "\\");
			imp = imp[dpos + 1 .. $];
		}

		int namesLength = mNames.length;
		foreach(string impdir; imports)
		{
			impdir = impdir ~ dir;
			if(!isExistingDir(impdir))
				continue;
			foreach(string name; dirEntries(impdir, SpanMode.shallow))
			{
				string base = baseName(name);
				string ext = toLower(extension(name));
				bool canImport = false;
				bool issubdir = isDir(name);
				if(issubdir)
					canImport = (ext.length == 0);
				else if(ext == ".d" || ext == ".di")
				{
					base = base[0 .. $-ext.length];
					canImport = true;
				}
				if(canImport && base.startsWith(imp))
				{
					string txt = base ~ (issubdir ? ":DIR" : ":MOD");
					addunique(mNames, txt);
				}
			}
		}
		return mNames.length > namesLength;
	}

	bool ImportExpansions(IVsTextView textView, Source src)
	{
		int line, idx;
		if(int hr = textView.GetCaretPos(&line, &idx))
			return false;

		wstring wimp = src.GetImportModule(line, idx, true);
		if(wimp.empty)
			return false;
		string txt = to!string(wimp);
		ImportExpansions(txt, src.GetFileName());
		return true;
	}

	///////////////////////////////////////////////////////////////
	string GetTokenBeforeCaret(IVsTextView textView, Source src)
	{
		int line, idx;
		int hr = textView.GetCaretPos(&line, &idx);
		assert(hr == S_OK);
		int startIdx, endIdx;
		if(!src.GetWordExtent(line, idx, WORDEXT_FINDTOKEN, startIdx, endIdx))
			return "";
		wstring txt = src.GetText(line, startIdx, line, idx);
		return toUTF8(txt);
	}

	bool NearbyExpansions(IVsTextView textView, Source src)
	{
		if(!Package.GetGlobalOptions().expandFromBuffer)
			return false;

		int line, idx;
		if(int hr = textView.GetCaretPos(&line, &idx))
			return false;
		int lineCount;
		src.mBuffer.GetLineCount(&lineCount);

		//mNames.length = 0;
		int start = max(0, line - kCompletionSearchLines);
		int end = min(lineCount, line + kCompletionSearchLines);

		string tok = GetTokenBeforeCaret(textView, src);
		if(tok.length && !dLex.isIdentifierCharOrDigit(tok.front))
			tok = "";

		int iState = src.mColorizer.GetLineState(start);
		if(iState == -1)
			return false;

		int namesLength = mNames.length;
		for(int ln = start; ln < end; ln++)
		{
			wstring text = src.GetText(ln, 0, ln, -1);
			uint pos = 0;
			while(pos < text.length)
			{
				uint ppos = pos;
				int type = dLex.scan(iState, text, pos);
				if(ln != line || pos < idx || ppos > idx)
					if(type == TokenCat.Identifier || type == TokenCat.Keyword)
					{
						string txt = toUTF8(text[ppos .. pos]);
						if(txt.startsWith(tok))
							addunique(mNames, txt);
					}
			}
		}
		return mNames.length > namesLength;
	}
	
	////////////////////////////////////////////////////////////////////////
	bool SymbolExpansions(IVsTextView textView, Source src)
	{
		if(!Package.GetGlobalOptions().expandFromJSON)
			return false;

		string tok = GetTokenBeforeCaret(textView, src);
		if(tok.length && !dLex.isIdentifierCharOrDigit(tok.front))
			tok = "";
		if(!tok.length)
			return false;
		
		int namesLength = mNames.length;
		addunique(mNames, Package.GetLibInfos().findCompletions(tok, true));
		return mNames.length > namesLength;
	}
	
	///////////////////////////////////////////////////////////////////////////

	bool SemanticExpansions(IVsTextView textView, Source src)
	{
		if(!Package.GetGlobalOptions().expandFromSemantics)
			return false;

		try
		{
			string tok = GetTokenBeforeCaret(textView, src);
			if(tok.length && !dLex.isIdentifierCharOrDigit(tok.front))
				tok = "";

			int line, idx;
			int hr = textView.GetCaretPos(&line, &idx);

			src.ensureCurrentTextParsed(); // pass new text before expansion request

			auto langsvc = Package.GetLanguageService();
			mPendingSource = src;
			mPendingView = textView;
			mPendingRequest = langsvc.GetSemanticExpansions(src, tok, line, idx, &OnExpansions);
			return true;
		}
		catch(Error e)
		{
			writeToBuildOutputPane(e.msg);
		}
		return false;
	}

	extern(D) void OnExpansions(uint request, string filename, string tok, int line, int idx, string[] symbols)
	{
		if(request != mPendingRequest)
			return;

		if(symbols.length > 0 && mPendingSource)
		{
			// split after second ':' to combine same name and type
			static string splitName(string name, ref string desc)
			{
				auto pos = name.indexOf(':');
				if(pos < 0)
					return name;
				pos = name.indexOf(':', pos + 1);
				if(pos < 0)
					return name;
				desc = name[pos..$];
				return name[0..pos];
			}

			// go through assoc array for faster uniqueness check
			string[string] names;
			foreach(n; mNames)
			{
				string desc;
				string name = splitName(n, desc);
				names[name] = desc;
			}
			foreach(s; symbols)
			{
				string desc;
				string name = splitName(s, desc);
				if(auto p = name in names)
					*p ~= "\a\a" ~ desc[1..$]; // strip ":"
				else
					names[name] = desc;
			}
			mNames.length = names.length;
			size_t i = 0;
			foreach(n, desc; names)
				mNames[i++] = n ~ desc;

			sort!("icmp(a, b) < 0", SwapStrategy.stable)(mNames);
			mPendingSource.GetCompletionSet().Init(mPendingView, this, false);
		}
		mPendingRequest = 0;
		mPendingView = null;
		mPendingSource = null;
	}

	uint mPendingRequest;
	IVsTextView mPendingView;
	Source mPendingSource;

	////////////////////////////////////////////////////////////////////////
	bool StartExpansions(IVsTextView textView, Source src, bool autoInsert)
	{
		mNames = mNames.init;
		mExpansionState = kStateInit;
		
		if(!_MoreExpansions(textView, src))
			return false;

		if(autoInsert)
		{
			while(GetCount() == 1 && _MoreExpansions(textView, src)) {}
			if(GetCount() == 1)
			{
				int line, idx, startIdx, endIdx;
				textView.GetCaretPos(&line, &idx);
				if(src.GetWordExtent(line, idx, WORDEXT_FINDTOKEN, startIdx, endIdx))
				{
					wstring txt = to!wstring(GetText(textView, 0));
					TextSpan changedSpan;
					src.mBuffer.ReplaceLines(line, startIdx, line, endIdx, txt.ptr, txt.length, &changedSpan);
					return true;
				}
			}
		}
		src.GetCompletionSet().Init(textView, this, false);
		return true;
	}

	bool _MoreExpansions(IVsTextView textView, Source src)
	{
		switch(mExpansionState)
		{
		case kStateInit:
			if(ImportExpansions(textView, src))
			{
				mExpansionState = kStateSymbols; // do not try other symbols but file imports
				return true;
			}
			goto case;
		case kStateImport:
			if(SemanticExpansions(textView, src))
			{
				mExpansionState = kStateSemantic;
				return true;
			}
			goto case;
		case kStateSemantic:
			if(NearbyExpansions(textView, src))
			{
				mExpansionState = kStateNearBy;
				return true;
			}
			goto case;
		case kStateNearBy:
			if(SymbolExpansions(textView, src))
			{
				mExpansionState = kStateSymbols;
				return true;
			}
			goto default;
		default:
			break;
		}
		return false;
	}

	bool MoreExpansions(IVsTextView textView, Source src)
	{
		_MoreExpansions(textView, src);
		src.GetCompletionSet().Init(textView, this, false);
		return true;
	}

	void StopExpansions()
	{
		mPendingRequest = 0;
		mPendingView = null;
		mPendingSource = null;
	}
}

class CompletionSet : DisposingComObject, IVsCompletionSet, IVsCompletionSetEx
{
	HIMAGELIST mImageList;
	bool mDisplayed;
	bool mCompleteWord;
	string mCommittedWord;
	dchar mCommitChar;
	int mCommitIndex;
	IVsTextView mTextView;
	Declarations mDecls;
	Source mSource;
	TextSpan mInitialExtent;
	bool mIsCommitted;
	bool mWasUnique;

	this(ImageList imageList, Source source)
	{
		mImageList = LoadImageList(g_hInst, MAKEINTRESOURCEA(BMP_COMPLETION), 16, 16);
		mSource = source;
	}

	override HRESULT QueryInterface(in IID* riid, void** pvObject)
	{
		if(queryInterface!(IVsCompletionSetEx) (this, riid, pvObject))
			return S_OK;
		if(queryInterface!(IVsCompletionSet) (this, riid, pvObject))
			return S_OK;
		if(*riid == uuid_IVsCoTaskMemFreeMyStrings) // avoid log message, implement?
			return E_NOTIMPL;
		return super.QueryInterface(riid, pvObject);
	}

	void Init(IVsTextView textView, Declarations declarations, bool completeWord)
	{
		Close();
		mTextView = textView;
		mDecls = declarations;
		mCompleteWord = completeWord;

		//check if we have members
		int count = mDecls.GetCount();
		if (count <= 0) return;

		//initialise and refresh      
		UpdateCompletionFlags flags = UCS_NAMESCHANGED;
		if (mCompleteWord)
			flags |= UCS_COMPLETEWORD;

		mWasUnique = false;

		int hr = textView.UpdateCompletionStatus(this, flags);
		assert(hr == S_OK);

		mDisplayed = (!mWasUnique || !completeWord);
	}

	override void Dispose()
	{
		Close();
		//if (imageList != null) imageList.Dispose();
		if(mImageList)
		{
			ImageList_Destroy(mImageList);
			mImageList = null;
		}
	}

	void Close()
	{
		if (mDisplayed && mTextView)
		{
			// Here we can't throw or exit because we need to call Dispose on
			// the disposable membres.
			try {
				mTextView.UpdateCompletionStatus(null, 0);
			} catch (Exception e) {
			}
		}
		mDisplayed = false;
		mTextView = null;
		mDecls = null;
	}


	dchar OnAutoComplete()
	{
		mIsCommitted = false;
		if (mDecls)
			return mDecls.OnAutoComplete(mTextView, mCommittedWord, mCommitChar, mCommitIndex);
		return '\0';
	}

	//--------------------------------------------------------------------------
	//IVsCompletionSet methods
	//--------------------------------------------------------------------------
	override int GetImageList(HANDLE *phImages)
	{
		mixin(LogCallMix);

		*phImages = cast(HANDLE)mImageList;
		return S_OK;
	}

	override int GetFlags()
	{
		mixin(LogCallMix);

		return CSF_HAVEDESCRIPTIONS | CSF_CUSTOMCOMMIT | CSF_INITIALEXTENTKNOWN | CSF_CUSTOMMATCHING;
	}

	override int GetCount()
	{
		mixin(LogCallMix);

		return mDecls.GetCount();
	}

	override int GetDisplayText(in int index, WCHAR** text, int* glyph)
	{
		//mixin(LogCallMix);

		if (glyph)
			*glyph = mDecls.GetGlyph(index);
		*text = allocBSTR(mDecls.GetDisplayText(index));
		return S_OK;
	}

	override int GetDescriptionText(in int index, BSTR* description)
	{
		mixin(LogCallMix2);

		*description = allocBSTR(mDecls.GetDescription(index));
		return S_OK;
	}

	override int GetInitialExtent(int* line, int* startIdx, int* endIdx)
	{
		mixin(LogCallMix);

		int idx;
		int hr = S_OK;
		if (mDecls.GetInitialExtent(mTextView, line, startIdx, endIdx))
			goto done;

		hr = mTextView.GetCaretPos(line, &idx);
		assert(hr == S_OK);
		hr = GetTokenExtent(*line, idx, *startIdx, *endIdx);

	done:
		// Remember the initial extent so we can pass it along on the commit.
		mInitialExtent.iStartLine = mInitialExtent.iEndLine = *line;
		mInitialExtent.iStartIndex = *startIdx;
		mInitialExtent.iEndIndex = *endIdx;

		//assert(TextSpanHelper.ValidCoord(mSource, line, startIdx) &&
		//       TextSpanHelper.ValidCoord(mSource, line, endIdx));
		return hr;
	}

	int GetTokenExtent(int line, int idx, out int startIdx, out int endIdx)
	{
		int hr = S_OK;
		bool rc = mSource.GetWordExtent(line, idx, WORDEXT_FINDTOKEN, startIdx, endIdx);

		if (!rc && idx > 0)
		{
			//rc = mSource.GetWordExtent(line, idx - 1, WORDEXT_FINDTOKEN, startIdx, endIdx);
			if (!rc)
			{
				// Must stop core text editor from looking at startIdx and endIdx since they are likely
				// invalid.  So we must return a real failure here, not just S_FALSE.
				startIdx = endIdx = idx;
				hr = E_NOTIMPL;
			}
		}
		// make sure the span is positive.
		endIdx = max(endIdx, idx);
		return hr;
	}

	override int GetBestMatch(in WCHAR* wtextSoFar, in int length, int* index, uint* flags)
	{
		mixin(LogCallMix);

		*flags = 0;
		*index = 0;

		bool uniqueMatch = false;
		string textSoFar = to_string(wtextSoFar);
		if (textSoFar.length != 0)
		{
			mDecls.GetBestMatch(textSoFar, index, &uniqueMatch);
			if (*index < 0 || *index >= mDecls.GetCount())
			{
				*index = 0;
				uniqueMatch = false;
			} else {
				// Indicate that we want to select something in the list.
				*flags = GBM_SELECT;
			}
		}
		else if (mDecls.GetCount() == 1 && mCompleteWord)
		{
			// Only one entry, and user has invoked "word completion", then
			// simply select this item.
			*index = 0;
			*flags = GBM_SELECT;
			uniqueMatch = true;
		}
		if (uniqueMatch)
		{
			*flags |= GBM_UNIQUE;
			mWasUnique = true;
		}
		return S_OK;
	}

	override int OnCommit(in WCHAR* wtextSoFar, in int index, in BOOL selected, in WCHAR commitChar, BSTR* completeWord)
	{
		mixin(LogCallMix);

		dchar ch = commitChar;
		bool isCommitChar = true;
		
		string textSoFar = to_string(wtextSoFar);
		if (commitChar != 0)
		{
			// if the char is in the list of given member names then obviously it
			// is not a commit char.
			int i = textSoFar.length;
			for (int j = 0, n = mDecls.GetCount(); j < n; j++)
			{
				string name = mDecls.GetText(mTextView, j);
				if (name.length > i && name[i] == commitChar)
				{
					if (i == 0 || name[0 .. i] == textSoFar)
						goto nocommit; // cannot be a commit char if it is an expected char in a matching name
				}
			}
			isCommitChar = mDecls.IsCommitChar(textSoFar, (selected == 0) ? -1 : index, ch);
		}

		if (isCommitChar)
		{
			mCommittedWord = mDecls.OnCommit(mTextView, textSoFar, ch, selected == 0 ? -1 : index, mInitialExtent);
			*completeWord = allocBSTR(mCommittedWord);
			mCommitChar = ch;
			mCommitIndex = index;
			mIsCommitted = true;
			return S_OK;
		}
	nocommit:
		// S_FALSE return means the character is not a commit character.
		*completeWord = allocBSTR(textSoFar);
		return S_FALSE;
	}

	override int Dismiss()
	{
		mixin(LogCallMix);

		mDisplayed = false;
		return S_OK;
	}

	// IVsCompletionSetEx Members
	override int CompareItems(in BSTR bstrSoFar, in BSTR bstrOther, in int lCharactersToCompare, int* plResult)
	{
		mixin(LogCallMix);

		*plResult = 0;
		return E_NOTIMPL;
	}

	override int IncreaseFilterLevel(in int iSelectedItem)
	{
		mixin(LogCallMix2);

		return E_NOTIMPL;
	}

	override int DecreaseFilterLevel(in int iSelectedItem)
	{
		mixin(LogCallMix2);

		return E_NOTIMPL;
	}

	override int GetCompletionItemColor(in int iIndex, COLORREF* dwFGColor, COLORREF* dwBGColor)
	{
		mixin(LogCallMix);

		*dwFGColor = *dwBGColor = 0;
		return E_NOTIMPL;
	}

	override int GetFilterLevel(int* iFilterLevel)
	{
		mixin(LogCallMix2);

		*iFilterLevel = 0;
		return E_NOTIMPL;
	}

	override int OnCommitComplete()
	{
		mixin(LogCallMix);

/+
		if(CodeWindowManager mgr = mSource.LanguageService.GetCodeWindowManagerForView(mTextView))
			if (ViewFilter filter = mgr.GetFilter(mTextView))
				filter.OnAutoComplete();
+/
		return S_OK;
	}
}

//-------------------------------------------------------------------------------------
class MethodData : DisposingComObject, IVsMethodData
{
	IServiceProvider mProvider;
	IVsMethodTipWindow mMethodTipWindow;
	
	Definition[] mMethods;
	bool mTypePrefixed = true;
	int mCurrentParameter;
	int mCurrentMethod;
	bool mDisplayed;
	IVsTextView mTextView;
	TextSpan mContext;

	this()
	{
		auto uuid = uuid_coclass_VsMethodTipWindow;
		mMethodTipWindow = VsLocalCreateInstance!IVsMethodTipWindow (&uuid, sdk.win32.wtypes.CLSCTX_INPROC_SERVER);
		if (mMethodTipWindow)
			mMethodTipWindow.SetMethodData(this);
	}

	override HRESULT QueryInterface(in IID* riid, void** pvObject)
	{
		if(queryInterface!(IVsMethodData) (this, riid, pvObject))
			return S_OK;
		return super.QueryInterface(riid, pvObject);
	}

	void Refresh(IVsTextView textView, Definition[] methods, int currentParameter, TextSpan context)
	{
		if (!mDisplayed)
			mCurrentMethod = 0; // methods.DefaultMethod;

		mContext = context;
		mMethods = mMethods.init;
	defLoop:
		foreach(ref def; methods)
		{
			foreach(ref d; mMethods)
				if(d.type == def.type)
				{
					if (!d.inScope.endsWith(" ..."))
						d.inScope ~= " ...";
					continue defLoop;
				}
			mMethods ~= def;
		}

		// Apparently this Refresh() method is called as a result of event notification
		// after the currentMethod is changed, so we do not want to Dismiss anything or
		// reset the currentMethod here. 
		//Dismiss();  
		mTextView = textView;

		mCurrentParameter = currentParameter;
		AdjustCurrentParameter(0);
	}

	void AdjustCurrentParameter(int increment)
	{
		mCurrentParameter += increment;
		if (mCurrentParameter < 0)
			mCurrentParameter = -1;
		else if (mCurrentParameter >= GetParameterCount(mCurrentMethod))
			mCurrentParameter = GetParameterCount(mCurrentMethod);

		UpdateView();
	}

	void Close()
	{
		Dismiss();
		mTextView = null;
		mMethods = null;
	}

	void Dismiss()
	{
		if (mDisplayed && mTextView)
			mTextView.UpdateTipWindow(mMethodTipWindow, UTW_DISMISS);

		OnDismiss();
	}

	override void Dispose()
	{
		Close();
		if (mMethodTipWindow)
			mMethodTipWindow.SetMethodData(null);
		mMethodTipWindow = release(mMethodTipWindow);
	}

    //IVsMethodData
	override int GetOverloadCount()
	{
		if (!mTextView || mMethods.length == 0)
			return 0;
		return mMethods.length;
	}

	override int GetCurMethod()
	{
		return mCurrentMethod;
	}

	override int NextMethod()
	{
		if (mCurrentMethod < GetOverloadCount() - 1)
			mCurrentMethod++;
		return mCurrentMethod;
	}

	override int PrevMethod()
	{
		if (mCurrentMethod > 0)
			mCurrentMethod--;
		return mCurrentMethod;
	}

	override int GetParameterCount(in int method)
	{
		if (mMethods.length == 0)
			return 0;
		if (method < 0 || method >= GetOverloadCount())
			return 0;

		return mMethods[method].GetParameterCount();
	}

	override int GetCurrentParameter(in int method)
	{
		return mCurrentParameter;
	}

	override void OnDismiss()
	{
		mTextView = null;
		mMethods = mMethods.init;
		mCurrentMethod = 0;
		mCurrentParameter = 0;
		mDisplayed = false;
	}

	override void UpdateView()
	{
		if (mTextView && mMethodTipWindow)
		{
			mTextView.UpdateTipWindow(mMethodTipWindow, UTW_CONTENTCHANGED | UTW_CONTEXTCHANGED);
			mDisplayed = true;
		}
	}

	override int GetContextStream(int* pos, int* length)
	{
		*pos = 0;
		*length = 0;
		int line, idx, vspace, endpos;
		if(HRESULT rc = mTextView.GetCaretPos(&line, &idx))
			return rc;
		
		line = max(line, mContext.iStartLine);
		if(HRESULT rc = mTextView.GetNearestPosition(line, mContext.iStartIndex, pos, &vspace))
			return rc;
		
		line = max(line, mContext.iEndLine);
		if(HRESULT rc = mTextView.GetNearestPosition(line, mContext.iEndIndex, &endpos, &vspace))
			return rc;

		*length = endpos - *pos;
		return S_OK;
	}

	override WCHAR* GetMethodText(in int method, in MethodTextType type)
	{
		if (mMethods.length == 0)
			return null;
		if (method < 0 || method >= GetOverloadCount())
			return null;

		string result;

		//a type
		if ((type == MTT_TYPEPREFIX && mTypePrefixed) ||
			(type == MTT_TYPEPOSTFIX && !mTypePrefixed))
		{
			string str = mMethods[method].GetReturnType();

			if (str.length == 0)
				return null;

			result = str; // mMethods.TypePrefix + str + mMethods.TypePostfix;
		}
		else
		{
			//other
			switch (type) {
			case MTT_OPENBRACKET:
				result = "("; // mMethods.OpenBracket;
				break;

			case MTT_CLOSEBRACKET:
				result = ")"; // mMethods.CloseBracket;
				break;

			case MTT_DELIMITER:
				result = ","; // mMethods.Delimiter;
				break;

			case MTT_NAME:
				result = mMethods[method].name;
				break;

			case MTT_DESCRIPTION:
				if(mMethods[method].help.length)
					result = phobosDdocExpand(mMethods[method].help);
				else if(mMethods[method].line > 0)
					result = format("%s %s @ %s(%d)", mMethods[method].kind, mMethods[method].inScope, mMethods[method].filename, mMethods[method].line);
				break;

			case MTT_TYPEPREFIX:
			case MTT_TYPEPOSTFIX:
			default:
				break;
			}
		}

		return result.length == 0 ? null : allocBSTR(result); // produces leaks?
	}

	override WCHAR* GetParameterText(in int method, in int parameter, in ParameterTextType type)
	{
		if (mMethods.length == 0)
			return null;
		if (method < 0 || method >= GetOverloadCount())
			return null;
		if (parameter < 0 || parameter >= GetParameterCount(method))
			return null;

		string name;
		string description;
		string display;

		mMethods[method].GetParameterInfo(parameter, name, display, description);

		string result;

		switch (type) {
		case PTT_NAME:
			result = name;
			break;

		case PTT_DESCRIPTION:
			result = description;
			break;

		case PTT_DECLARATION:
			result = display;
			break;

		default:
			break;
		}
		return result.length == 0 ? null : allocBSTR(result); // produces leaks?
	}
}
