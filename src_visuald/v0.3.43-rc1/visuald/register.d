// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module visuald.register;

import visuald.windows;
import sdk.win32.winreg;

import std.string;
import std.conv;
import std.utf;
import std.path;
import std.file;
import std.datetime;
import std.array;

import stdext.string;
import stdext.registry;

import visuald.dpackage;
import visuald.dllmain;
import visuald.propertypage;
import visuald.config;
import visuald.comutil;

// Registers COM objects normally and registers VS Packages to the specified VS registry hive under HKCU
extern(Windows)
HRESULT VSDllRegisterServerUser(in wchar* strRegRoot)
{
	return VSDllRegisterServerInternal(strRegRoot, true);
}

// Unregisters COM objects normally and unregisters VS Packages from the specified VS registry hive under HKCU
extern(Windows)
HRESULT VSDllUnregisterServerUser(in wchar* strRegRoot)
{
	return VSDllUnregisterServerInternal(strRegRoot, true);
}

// Registers COM objects normally and registers VS Packages to the specified VS registry hive
extern(Windows)
HRESULT VSDllRegisterServer(in wchar* strRegRoot)
{
	return VSDllRegisterServerInternal(strRegRoot, false);
}

// Unregisters COM objects normally and unregisters VS Packages from the specified VS registry hive
extern(Windows)
HRESULT VSDllUnregisterServer(in wchar* strRegRoot)
{
	return VSDllUnregisterServerInternal(strRegRoot, false);
}

// Registers COM objects normally and registers VS Packages to the default VS registry hive
extern(Windows)
HRESULT DllRegisterServer()
{
	return VSDllRegisterServer(null);
}

// Unregisters COM objects normally and unregisters VS Packages from the default VS registry hive
extern(Windows)
HRESULT DllUnregisterServer()
{
	return VSDllUnregisterServer(null);
}

extern(Windows)
HRESULT WriteExtensionPackageDefinition(in wchar* args)
{
	wstring wargs = to_wstring(args);
	auto idx = indexOf(wargs, ' ');
	if(idx < 1)
		return E_FAIL;
	registryDump = "Windows Registry Editor Version 5.00\n"w;
	registryRoot = (wargs[0 .. idx] ~ "\0"w)[0 .. idx];
	string fname = to!string(wargs[idx + 1 .. $]);
	try
	{
		HRESULT rc = VSDllRegisterServerInternal(registryRoot.ptr, false);
		if(rc != S_OK)
			return rc;
		string dir = dirName(fname);
		if(!exists(dir))
			mkdirRecurse(dir);

		std.file.write(fname, (cast(wchar) 0xfeff) ~ registryDump); // add BOM
		return S_OK;
	}
	catch(Exception e)
	{
		MessageBox(null, toUTF16z(e.msg), args, MB_OK);
	}
	return E_FAIL;
}

///////////////////////////////////////////////////////////////////////

wstring registryDump;
wstring registryRoot;

class RegistryException : Exception
{
	this(HRESULT hr)
	{
		super("Registry Error");
		result = hr;
	}

	HRESULT result;
}

class RegKey
{
	this(HKEY root, wstring keyname, bool write = true, bool chkDump = true, bool x64hive = false)
	{
		Create(root, keyname, write, chkDump, x64hive);
	}

	~this()
	{
		Close();
	}

	void Close()
	{
		if(key)
		{
			RegCloseKey(key);
			key = null;
		}
	}

	static wstring registryName(wstring name)
	{
		if(name.length == 0)
			return "@"w;
		return  "\""w ~ escapeString(name) ~ "\""w;
	}

	void Create(HKEY root, wstring keyname, bool write = true, bool chkDump = true, bool x64hive = false)
	{
		HRESULT hr;
		if(write && chkDump && registryRoot.length && keyname.startsWith(registryRoot))
		{
			if (keyname.startsWith(registryRoot))
				registryDump ~= "\n[$RootKey$"w ~ keyname[registryRoot.length..$] ~ "]\n"w;
			else
				registryDump ~= "\n[\\"w ~ keyname ~ "]\n"w;
		}
		else if(write)
		{
			auto opt = REG_OPTION_NON_VOLATILE | (x64hive ? KEY_WOW64_64KEY : 0);
			hr = hrRegCreateKeyEx(root, keyname, 0, null, opt, KEY_WRITE, null, &key, null);
			if(FAILED(hr))
				throw new RegistryException(hr);
		}
		else
			hr = hrRegOpenKeyEx(root, keyname, (x64hive ? KEY_WOW64_64KEY : 0), KEY_READ, &key);
	}

	void Set(wstring name, wstring value, bool escape = true)
	{
		if(!key && registryRoot.length)
		{
			if(escape)
				value = escapeString(value);
			registryDump ~= registryName(name) ~ "=\""w ~ value ~ "\"\n"w;
			return;
		}
		if(!key)
			throw new RegistryException(E_FAIL);
			
		HRESULT hr = RegCreateValue(key, name, value);
		if(FAILED(hr))
			throw new RegistryException(hr);
	}

	void Set(wstring name, uint value)
	{
		if(!key && registryRoot.length)
		{
			registryDump ~= registryName(name) ~ "=dword:"w;
			registryDump ~= to!wstring(format("%08x", value)) ~ "\n";
			return;
		}
		if(!key)
			throw new RegistryException(E_FAIL);

		HRESULT hr = RegCreateDwordValue(key, name, value);
		if(FAILED(hr))
			throw new RegistryException(hr);
	}

	void Set(wstring name, long value)
	{
		if(!key && registryRoot.length)
		{
			registryDump ~= registryName(name) ~ "=qword:"w;
			registryDump ~= to!wstring(to!string(value, 16) ~ "\n");
			return;
		}
		if(!key)
			throw new RegistryException(E_FAIL);

		HRESULT hr = RegCreateQwordValue(key, name, value);
		if(FAILED(hr))
			throw new RegistryException(hr);
	}

	void Set(wstring name, void[] data)
	{
		if(!key)
			throw new RegistryException(E_FAIL);
		
		HRESULT hr = RegCreateBinaryValue(key, name, data);
		if(FAILED(hr))
			throw new RegistryException(hr);
	}
	
	bool Delete(wstring name)
	{
		if(!key && registryRoot.length)
			return true; // ignore
		if(!key)
			return false;
		wchar* szName = _toUTF16zw(name);
		HRESULT hr = RegDeleteValue(key, szName);
		return SUCCEEDED(hr);
	}
	
	wstring GetString(wstring name, wstring def = "")
	{
		if(!key)
			return def;
		
		wchar[260] buf;
		DWORD cnt = 260 * wchar.sizeof;
		wchar* szName = _toUTF16zw(name);
		DWORD type;
		int hr = RegQueryValueExW(key, szName, null, &type, cast(ubyte*) buf.ptr, &cnt);
		if(hr == S_OK && cnt > 0)
			return to_wstring(buf.ptr);
		if(hr != ERROR_MORE_DATA || type != REG_SZ)
			return def;

		scope wchar[] pbuf = new wchar[cnt/2 + 1];
		RegQueryValueExW(key, szName, null, &type, cast(ubyte*) pbuf.ptr, &cnt);
		return to_wstring(pbuf.ptr);
	}

	DWORD GetDWORD(wstring name, DWORD def = 0)
	{
		if(!key)
			return def;
		
		DWORD dw, type, cnt = dw.sizeof;
		wchar* szName = _toUTF16zw(name);
		int hr = RegQueryValueExW(key, szName, null, &type, cast(ubyte*) &dw, &cnt);
		if(hr != S_OK || type != REG_DWORD)
			return def;
		return dw;
	}
	
	void[] GetBinary(wstring name)
	{
		if(!key)
			return null;
		
		wchar* szName = _toUTF16zw(name);
		DWORD type, cnt = 0;
		int hr = RegQueryValueExW(key, szName, null, &type, cast(ubyte*) &type, &cnt);
		if(hr != ERROR_MORE_DATA || type != REG_BINARY)
			return null;
		
		ubyte[] data = new ubyte[cnt];
		hr = RegQueryValueExW(key, szName, null, &type, data.ptr, &cnt);
		if(hr != S_OK)
			return null;
		return data;
	}
	
	HKEY key;
}

///////////////////////////////////////////////////////////////////////
// convention: no trailing "\" for keys

static const wstring regPathConfigDefault  = "Software\\Microsoft\\VisualStudio\\9.0"w;

static const wstring regPathFileExts       = "\\Languages\\File Extensions"w;
static const wstring regPathLServices      = "\\Languages\\Language Services"w;
static const wstring regPathCodeExpansions = "\\Languages\\CodeExpansions"w;
static const wstring regPathPrjTemplates   = "\\NewProjectTemplates\\TemplateDirs"w;
static const wstring regPathProjects       = "\\Projects"w;
static const wstring regPathToolsOptions   = "\\ToolsOptionsPages\\Projects\\Visual D Settings"w;
static const wstring regPathToolsDirsOld   = "\\ToolsOptionsPages\\Projects\\Visual D Directories"w;
static const wstring regPathToolsDirsDmd   = "\\ToolsOptionsPages\\Projects\\Visual D Settings\\DMD Directories"w;
static const wstring regPathToolsDirsGdc   = "\\ToolsOptionsPages\\Projects\\Visual D Settings\\GDC Directories"w;
static const wstring regPathToolsDirsLdc   = "\\ToolsOptionsPages\\Projects\\Visual D Settings\\LDC Directories"w;
static const wstring regMiscFiles          = regPathProjects ~ "\\{A2FE74E1-B743-11d0-AE1A-00A0C90FFFC3}"w;
static const wstring regPathMetricsExcpt   = "\\AD7Metrics\\Exception"w;
static const wstring regPathMetricsEE      = "\\AD7Metrics\\ExpressionEvaluator"w;

static const wstring vendorMicrosoftGuid   = "{994B45C4-E6E9-11D2-903F-00C04FA302A1}"w;
static const wstring guidCOMPlusNativeEng  = "{92EF0900-2251-11D2-B72E-0000F87572EF}"w;

///////////////////////////////////////////////////////////////////////
//  Registration
///////////////////////////////////////////////////////////////////////

wstring GetRegistrationRoot(in wchar* pszRegRoot, bool useRanu)
{
	wstring szRegistrationRoot;

	// figure out registration root, append "Configuration" in the case of RANU
	if (pszRegRoot is null)
		szRegistrationRoot = regPathConfigDefault;
	else
		szRegistrationRoot = to_wstring(pszRegRoot);
	if(useRanu)
	{
		scope RegKey keyConfig = new RegKey(HKEY_CURRENT_USER, szRegistrationRoot ~ "_Config"w, false);
		if(keyConfig.key)
			szRegistrationRoot ~= "_Config"w; // VS2010
		else
			szRegistrationRoot ~= "\\Configuration"w;
	}
	return szRegistrationRoot;
}

float guessVSVersion(wstring registrationRoot)
{
	auto idx = lastIndexOf(registrationRoot, '\\');
	if(idx < 0)
		return 0;
	wstring txt = registrationRoot[idx + 1 .. $];
	return parse!float(txt);
}

void updateConfigurationChanged(HKEY keyRoot, wstring registrationRoot)
{
	float ver = guessVSVersion(registrationRoot);
	//MessageBoxA(null, text("version: ", ver, "\nregkey: ", to!string(registrationRoot)).ptr, to!string(registrationRoot).ptr, MB_OK);
	if(ver >= 11)
	{
		scope RegKey keyRegRoot = new RegKey(keyRoot, registrationRoot, true, false);

		FILETIME fileTime;
		GetSystemTimeAsFileTime(&fileTime);
		ULARGE_INTEGER ul;
		ul.HighPart = fileTime.dwHighDateTime;
		ul.LowPart = fileTime.dwLowDateTime;
		ulong tempHNSecs = ul.QuadPart;

		keyRegRoot.Set("ConfigurationChanged", tempHNSecs);
	}
}

void fixVS2012Shellx64Debugger(HKEY keyRoot, wstring registrationRoot)
{
	float ver = guessVSVersion(registrationRoot);
	//MessageBoxA(null, text("version: ", ver, "\nregkey: ", to!string(registrationRoot)).ptr, to!string(registrationRoot).ptr, MB_OK);
	if(ver >= 11)
	{
		scope RegKey keyDebugger = new RegKey(keyRoot, registrationRoot ~ "\\Debugger"w);
		keyDebugger.Set("msvsmon-pseudo_remote"w, r"$ShellFolder$\Common7\Packages\Debugger\X64\msvsmon.exe"w, false);
	}
}

HRESULT VSDllUnregisterServerInternal(in wchar* pszRegRoot, in bool useRanu)
{
	HKEY keyRoot = useRanu ? HKEY_CURRENT_USER : HKEY_LOCAL_MACHINE;
	wstring registrationRoot = GetRegistrationRoot(pszRegRoot, useRanu);

	wstring packageGuid = GUID2wstring(g_packageCLSID);
	wstring languageGuid = GUID2wstring(g_languageCLSID);
	wstring wizardGuid = GUID2wstring(g_ProjectItemWizardCLSID);
	wstring vdhelperGuid = GUID2wstring(g_VisualDHelperCLSID);

	HRESULT hr = S_OK;
	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ "\\Packages\\"w ~ packageGuid);
	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ "\\CLSID\\"w ~ languageGuid);
	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ "\\CLSID\\"w ~ wizardGuid);
	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ "\\CLSID\\"w ~ vdhelperGuid);

	foreach (wstring fileExt; g_languageFileExtensions)
		hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ regPathFileExts ~ "\\"w ~ fileExt);

	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ "\\Services\\"w ~ languageGuid);
	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ "\\InstalledProducts\\"w ~ g_packageName);

	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ regPathLServices ~ "\\"w ~ g_languageName);
	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ regPathCodeExpansions ~ "\\"w ~ g_languageName);

	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ regPathPrjTemplates ~ "\\"w ~ packageGuid);
	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ regPathProjects ~ "\\"w ~ GUID2wstring(g_projectFactoryCLSID));
	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ regMiscFiles ~ "\\AddItemTemplates\\TemplateDirs\\"w ~ packageGuid);

	hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ regPathToolsOptions);

	foreach(guid; guids_propertyPages)
		hr |= RegDeleteRecursive(keyRoot, registrationRoot ~ "\\CLSID\\"w ~ GUID2wstring(*guid));

	hr |= RegDeleteRecursive(HKEY_CLASSES_ROOT, "CLSID\\"w ~ GUID2wstring(g_unmarshalEnumOutCLSID));
	static if(is(typeof(g_unmarshalTargetInfoCLSID))) 
		hr |= RegDeleteRecursive(HKEY_CLASSES_ROOT, "CLSID\\"w ~ GUID2wstring(g_unmarshalTargetInfoCLSID));

	scope RegKey keyToolMenu = new RegKey(keyRoot, registrationRoot ~ "\\Menus"w);
	keyToolMenu.Delete(packageGuid);

	updateConfigurationChanged(keyRoot, registrationRoot);
	return hr;
}

HRESULT VSDllRegisterServerInternal(in wchar* pszRegRoot, in bool useRanu)
{
	HKEY    keyRoot = useRanu ? HKEY_CURRENT_USER : HKEY_LOCAL_MACHINE;
	wstring registrationRoot = GetRegistrationRoot(pszRegRoot, useRanu);
	wstring dllPath = GetDLLName(g_hInst);
	wstring templatePath = GetTemplatePath(dllPath);
	wstring vdextPath = dirName(dllPath) ~ "\\vdextensions.dll"w;

	try
	{
		wstring packageGuid = GUID2wstring(g_packageCLSID);
		wstring languageGuid = GUID2wstring(g_languageCLSID);
		wstring debugLangGuid = GUID2wstring(g_debuggerLanguage);
		wstring exprEvalGuid = GUID2wstring(g_expressionEvaluator);
		wstring wizardGuid = GUID2wstring(g_ProjectItemWizardCLSID);
		wstring vdhelperGuid = GUID2wstring(g_VisualDHelperCLSID);

		// package
		scope RegKey keyPackage = new RegKey(keyRoot, registrationRoot ~ "\\Packages\\"w ~ packageGuid);
		keyPackage.Set(null, g_packageName);
		keyPackage.Set("InprocServer32"w, dllPath);
		keyPackage.Set("About"w, g_packageName);
		keyPackage.Set("CompanyName"w, g_packageCompany);
		keyPackage.Set("ProductName"w, g_packageName);
		keyPackage.Set("ProductVersion"w, toUTF16(g_packageVersion));
		keyPackage.Set("MinEdition"w, "Standard");
		keyPackage.Set("ID"w, 1);

		int bspos = dllPath.length - 1;	while (bspos >= 0 && dllPath[bspos] != '\\') bspos--;
		scope RegKey keySatellite = new RegKey(keyRoot, registrationRoot ~ "\\Packages\\"w ~ packageGuid ~ "\\SatelliteDll"w);
		keySatellite.Set("Path"w, dllPath[0 .. bspos+1]);
		keySatellite.Set("DllName"w, ".."w ~ dllPath[bspos .. $]);

		scope RegKey keyCLSID = new RegKey(keyRoot, registrationRoot ~ "\\CLSID\\"w ~ languageGuid);
		keyCLSID.Set("InprocServer32"w, dllPath);
		keyCLSID.Set("ThreadingModel"w, "Free"w); // Appartment?

		// Wizards
		scope RegKey keyWizardCLSID = new RegKey(keyRoot, registrationRoot ~ "\\CLSID\\"w ~ wizardGuid);
		keyWizardCLSID.Set("InprocServer32"w, dllPath);
		keyWizardCLSID.Set("ThreadingModel"w, "Appartment"w);

		// VDExtensions
		scope RegKey keyHelperCLSID = new RegKey(keyRoot, registrationRoot ~ "\\CLSID\\"w ~ vdhelperGuid);
		keyHelperCLSID.Set("InprocServer32"w, "mscoree.dll");
		keyHelperCLSID.Set("ThreadingModel"w, "Both"w);
		keyHelperCLSID.Set(null, "vdextensions.VisualDHelper"w);
		keyHelperCLSID.Set("Class"w, "vdextensions.VisualDHelper"w);
		keyHelperCLSID.Set("CodeBase"w, vdextPath);

		// file extensions
		wstring fileExtensions;
		foreach (wstring fileExt; g_languageFileExtensions)
		{
			scope RegKey keyExt = new RegKey(keyRoot, registrationRoot ~ regPathFileExts ~ "\\"w ~ fileExt);
			keyExt.Set(null, languageGuid);
			keyExt.Set("Name"w, g_languageName);
			fileExtensions ~= fileExt ~ ";"w;
		}

		// language service
		wstring langserv = registrationRoot ~ regPathLServices ~ "\\"w ~ g_languageName;
		scope RegKey keyLang = new RegKey(keyRoot, langserv);
		keyLang.Set(null, languageGuid);
		keyLang.Set("Package"w, packageGuid);
		keyLang.Set("Extensions"w, fileExtensions);
		keyLang.Set("LangResId"w, 0);
		foreach (ref const(LanguageProperty) prop; g_languageProperties)
			keyLang.Set(prop.name, prop.value);
		
		// colorizer settings
		scope RegKey keyColorizer = new RegKey(keyRoot, langserv ~ "\\EditorToolsOptions\\Colorizer"w);
		keyColorizer.Set("Package"w, packageGuid);
		keyColorizer.Set("Page"w, GUID2wstring(g_ColorizerPropertyPage));
		
		// intellisense settings
		scope RegKey keyIntellisense = new RegKey(keyRoot, langserv ~ "\\EditorToolsOptions\\Intellisense"w);
		keyIntellisense.Set("Package"w, packageGuid);
		keyIntellisense.Set("Page"w, GUID2wstring(g_IntellisensePropertyPage));

		scope RegKey keyService = new RegKey(keyRoot, registrationRoot ~ "\\Services\\"w ~ languageGuid);
		keyService.Set(null, packageGuid);
		keyService.Set("Name"w, g_languageName);
		
		scope RegKey keyProduct = new RegKey(keyRoot, registrationRoot ~ "\\InstalledProducts\\"w ~ g_packageName);
		keyProduct.Set("Package"w, packageGuid);
		keyProduct.Set("UseInterface"w, 1);

		// snippets
		wstring codeExp = registrationRoot ~ regPathCodeExpansions ~ "\\"w ~ g_languageName;
		scope RegKey keyCodeExp = new RegKey(keyRoot, codeExp);
		keyCodeExp.Set(null, languageGuid);
		keyCodeExp.Set("DisplayName"w, "131"w); // ???
		keyCodeExp.Set("IndexPath"w, templatePath ~ "\\CodeSnippets\\SnippetsIndex.xml"w);
		keyCodeExp.Set("LangStringId"w, g_languageName);
		keyCodeExp.Set("Package"w, packageGuid);
		keyCodeExp.Set("ShowRoots"w, 0);

		wstring snippets = templatePath ~ "\\CodeSnippets\\Snippets\\;%MyDocs%\\Code Snippets\\" ~ g_languageName ~ "\\My Code Snippets\\"w;
		scope RegKey keyCodeExp1 = new RegKey(keyRoot, codeExp ~ "\\ForceCreateDirs"w);
		keyCodeExp1.Set(g_languageName, snippets);

		scope RegKey keyCodeExp2 = new RegKey(keyRoot, codeExp ~ "\\Paths"w);
		keyCodeExp2.Set(g_languageName, snippets);

		scope RegKey keyPrjTempl = new RegKey(keyRoot, registrationRoot ~ regPathPrjTemplates ~ "\\"w ~ packageGuid ~ "\\/1");
		keyPrjTempl.Set(null, g_languageName);
		keyPrjTempl.Set("DeveloperActivity"w, g_languageName);
		keyPrjTempl.Set("SortPriority"w, 20);
		keyPrjTempl.Set("TemplatesDir"w, templatePath ~ "\\Projects"w);
		keyPrjTempl.Set("Folder"w, "{152CDB9D-B85A-4513-A171-245CE5C61FCC}"w); // other languages

		// project
		wstring projects = registrationRoot ~ "\\Projects\\"w ~ GUID2wstring(g_projectFactoryCLSID);
		scope RegKey keyProject = new RegKey(keyRoot, projects);
		keyProject.Set(null, "DProjectFactory"w);
		keyProject.Set("DisplayName"w, g_languageName);
		keyProject.Set("DisplayProjectFileExtensions"w, g_languageName ~ " Project Files (*."w ~ g_projectFileExtensions ~ ");*."w ~ g_projectFileExtensions);
		keyProject.Set("Package"w, packageGuid);
		keyProject.Set("DefaultProjectExtension"w, g_projectFileExtensions);
		keyProject.Set("PossibleProjectExtensions"w, g_projectFileExtensions);
		keyProject.Set("ProjectTemplatesDir"w, templatePath ~ "\\Projects"w);
		keyProject.Set("Language(VsTemplate)"w, g_languageName);
		keyProject.Set("ItemTemplatesDir"w, templatePath ~ "\\Items"w);

		// file templates
		scope RegKey keyProject1 = new RegKey(keyRoot, projects ~ "\\AddItemTemplates\\TemplateDirs\\"w ~ packageGuid ~ "\\/1"w);
		keyProject1.Set(null, g_languageName);
		keyProject1.Set("TemplatesDir"w, templatePath ~ "\\Items"w);
		keyProject1.Set("SortPriority"w, 25);

		// Miscellaneous Files Project
		scope RegKey keyProject2 = new RegKey(keyRoot, registrationRoot ~ regMiscFiles ~ "\\AddItemTemplates\\TemplateDirs\\"w ~ packageGuid ~ "\\/1"w);
		keyProject2.Set(null, g_languageName);
		keyProject2.Set("TemplatesDir"w, templatePath ~ "\\Items"w);
		keyProject2.Set("SortPriority"w, 25);

		// property pages
		foreach(guid; guids_propertyPages)
		{
			scope RegKey keyProp = new RegKey(keyRoot, registrationRoot ~ "\\CLSID\\"w ~ GUID2wstring(*guid));
			keyProp.Set("InprocServer32"w, dllPath);
			keyProp.Set("ThreadingModel"w, "Appartment"w);
		}

version(none){
		// expression evaluator
		scope RegKey keyLangDebug = new RegKey(keyRoot, langserv ~ "\\Debugger Languages\\"w ~ debugLangGuid);
		keyLangDebug.Set(null, g_languageName);
		
		scope RegKey keyLangException = new RegKey(keyRoot, registrationRoot ~ regPathMetricsExcpt ~ "\\"w ~ debugLangGuid ~ "\\D Exceptions");

		wstring langEE = registrationRoot ~ regPathMetricsEE ~ "\\"w ~ debugLangGuid ~ "\\"w ~ vendorMicrosoftGuid;
		scope RegKey keyLangEE = new RegKey(keyRoot, langEE);
		keyLangEE.Set("CLSID"w, exprEvalGuid);
		keyLangEE.Set("Language"w, g_languageName);
		keyLangEE.Set("Name"w, "D EE"w);
			
		scope RegKey keyEngine = new RegKey(keyRoot, langEE ~ "\\Engine");
		keyEngine.Set("0"w, guidCOMPlusNativeEng);
}

		// menu
		scope RegKey keyToolMenu = new RegKey(keyRoot, registrationRoot ~ "\\Menus"w);
		keyToolMenu.Set(packageGuid, ",2001,20"); // CTMENU,version
		
		// Visual D settings
		scope RegKey keyToolOpts = new RegKey(keyRoot, registrationRoot ~ regPathToolsOptions);
		keyToolOpts.Set(null, "Visual D Settings");
		keyToolOpts.Set("Package"w, packageGuid);
		keyToolOpts.Set("Page"w, GUID2wstring(g_ToolsProperty2Page));

		// remove old page
		RegDeleteRecursive(keyRoot, registrationRoot ~ regPathToolsDirsOld);

		scope RegKey keyToolOptsDmd = new RegKey(keyRoot, registrationRoot ~ regPathToolsDirsDmd);
		keyToolOptsDmd.Set(null, "DMD Directories");
		keyToolOptsDmd.Set("Package"w, packageGuid);
		keyToolOptsDmd.Set("Page"w, GUID2wstring(g_DmdDirPropertyPage));

		scope RegKey keyToolOptsGdc = new RegKey(keyRoot, registrationRoot ~ regPathToolsDirsGdc);
		keyToolOptsGdc.Set(null, "GDC Directories");
		keyToolOptsGdc.Set("Package"w, packageGuid);
		keyToolOptsGdc.Set("Page"w, GUID2wstring(g_GdcDirPropertyPage));

		scope RegKey keyToolOptsLdc = new RegKey(keyRoot, registrationRoot ~ regPathToolsDirsLdc);
		keyToolOptsLdc.Set(null, "LDC Directories");
		keyToolOptsLdc.Set("Package"w, packageGuid);
		keyToolOptsLdc.Set("Page"w, GUID2wstring(g_LdcDirPropertyPage));

		// remove "SkipLoading" entry from user settings
		scope RegKey userKeyPackage = new RegKey(HKEY_CURRENT_USER, registrationRoot ~ "\\Packages\\"w ~ packageGuid);
		userKeyPackage.Delete("SkipLoading");

		// remove Text Editor FontsAndColors Cache to add new Colors provided by Visual D
		RegDeleteRecursive(HKEY_CURRENT_USER, registrationRoot ~ "\\FontAndColors\\Cache"); // \\{A27B4E24-A735-4D1D-B8E7-9716E1E3D8E0}");

		// global registry keys for marshalled objects
		void registerMarshalObject(ref in GUID iid)
		{
			scope RegKey keyMarshal1 = new RegKey(HKEY_CLASSES_ROOT, "CLSID\\"w ~ GUID2wstring(iid) ~ "\\InprocServer32"w);
			keyMarshal1.Set(null, dllPath);
			keyMarshal1.Set("ThreadingModel"w, "Both"w);
			scope RegKey keyMarshal2 = new RegKey(HKEY_CLASSES_ROOT, "CLSID\\"w ~ GUID2wstring(iid) ~ "\\InprocHandler32"w);
			keyMarshal2.Set(null, dllPath);
		}
		registerMarshalObject(g_unmarshalEnumOutCLSID);
		static if(is(typeof(g_unmarshalTargetInfoCLSID))) 
			registerMarshalObject(g_unmarshalTargetInfoCLSID);

		fixVS2012Shellx64Debugger(keyRoot, registrationRoot);

		updateConfigurationChanged(keyRoot, registrationRoot);
	}
	catch(RegistryException e)
	{
		return e.result;
	}
	return S_OK;
}

wstring GetDLLName(HINSTANCE inst)
{
	//get dll path
	wchar[MAX_PATH+1] dllPath;
	DWORD dwLen = GetModuleFileNameW(inst, dllPath.ptr, MAX_PATH);
	if (dwLen == 0)
		throw new RegistryException(HRESULT_FROM_WIN32(GetLastError()));
	if (dwLen == MAX_PATH)
		throw new RegistryException(HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER));

	return to_wstring(dllPath.ptr);
}
 
wstring GetTemplatePath(wstring dllpath)
{
	string path = toUTF8(dllpath);
	path = dirName(path);
	debug path = dirName(dirName(path)) ~ "\\visuald";
	path = path ~ "\\Templates";
	return toUTF16(path);
}

