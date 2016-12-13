//
// Written and provided by Benjamin Thaut
// Complications improved by Rainer Schuetze
//
// file access monitoring added by Rainer Schuetze, needs filemonitor.dll in the same
//  directory as pipedmd.exe

module pipedmd;

import std.stdio;
import core.sys.windows.windows;
import std.windows.charset;
import core.stdc.string;
import std.string;
import std.regex;
import core.demangle;
import std.array;
import std.algorithm;
import std.conv;
import std.path;
import std.process;
import std.utf;

alias core.stdc.stdio.stdout stdout;

static bool isIdentifierChar(char ch)
{
	// include C++,Pascal,Windows mangling and UTF8 encoding and compression
	return ch >= 0x80 || (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_';
}

static bool isDigit(char ch)
{
	return (ch >= '0' && ch <= '9');
}

string quoteArg(string arg)
{
	if(indexOf(arg, ' ') < arg.length)
		return "\"" ~ replace(arg, "\"", "\\\"") ~ "\"";
	else
		return arg;
}

int main(string[] argv)
{
	if(argv.length < 2)
	{
		printf("pipedmd V0.2, written 2012 by Benjamin Thaut, complications improved by Rainer Schuetze\n");
		printf("decompresses and demangles names in OPTLINK and ld messages\n");
		printf("\n");
		printf("usage: %.*s [-nodemangle] [-gdcmode | -msmode] [-deps depfile] [executable] [arguments]\n",
			   argv[0].length, argv[0].ptr);
		return -1;
	}
	int skipargs = 0;
	string depsfile;
	bool doDemangle = true;
	bool demangleAll = false; //not just linker messages
	bool gdcMode = false; //gcc linker
	bool msMode = false; //microsoft linker
	bool verbose = false;

	while (argv.length >= skipargs + 2)
	{
		if(argv[skipargs + 1] == "-nodemangle")
		{
			doDemangle = false;
			skipargs++;
		}
		else if(argv[skipargs + 1] == "-demangleall")
		{
			demangleAll = true;
			skipargs++;
		}
		else if(argv[skipargs + 1] == "-gdcmode")
		{
			gdcMode = true;
			skipargs++;
		}
		else if(argv[skipargs + 1] == "-msmode")
		{
			msMode = true;
			skipargs++;
		}
		else if(argv[skipargs + 1] == "-verbose")
		{
			verbose = true;
			skipargs++;
		}
		else if(argv[skipargs + 1] == "-deps")
			depsfile = argv[skipargs += 2];
		else
			break;
	}

	string exe = (argv.length > skipargs + 1 ? argv[skipargs + 1] : null);
	string command;
	string trackdir;
	string trackfile;
	string trackfilewr;

	bool inject = false;
	if (depsfile.length > 0)
	{
		string fullexe = findExeInPath(exe);
		bool isX64 = isExe64bit(fullexe);
		if (verbose)
			if (fullexe.empty)
				printf ("%.*s not found in PATH, assuming %d-bit application\n", exe.length, exe.ptr, isX64 ? 64 : 32);
			else
				printf ("%.*s is a %d-bit application\n", fullexe.length, fullexe.ptr, isX64 ? 64 : 32);

		string tracker = findTracker(isX64);
		if (tracker.length > 0)
		{
			command = quoteArg(tracker);
			trackdir = dirName(depsfile);
			if (trackdir != ".")
				command ~= " /if " ~ quoteArg(trackdir);
			trackfile = stripExtension(baseName(exe)) ~ ".read.*.tlog";
			trackfilewr = stripExtension(baseName(exe)) ~ ".write.*.tlog";
			foreach(f; std.file.dirEntries(trackdir, std.file.SpanMode.shallow))
				if (globMatch(baseName(f), trackfile) || globMatch(baseName(f), trackfilewr))
					std.file.remove(f.name);
			command ~= " /c";
		}
		else if (isX64)
		{
			printf("cannot monitor 64-bit executable %.*s, no suitable tracker.exe found\n", exe.length, exe.ptr);
			return -1;
		}
		else
			inject = true;
	}

	for(int i = skipargs + 1;i < argv.length; i++)
	{
		if(command.length > 0)
			command ~= " ";
		command ~= quoteArg(argv[i]);
	}
	if(verbose)
		printf("Command: %.*s\n", command.length, command.ptr);

	int exitCode = runProcess(command, inject ? depsfile : null, doDemangle, demangleAll, gdcMode, msMode);

	if (exitCode == 0 && trackfile.length > 0)
	{
		// read read.*.tlog and remove all files found in write.*.log
		string rdbuf;
		string wrbuf;
		foreach(f; std.file.dirEntries(trackdir, std.file.SpanMode.shallow))
		{
			bool rd = globMatch(baseName(f), trackfile);
			bool wr = globMatch(baseName(f), trackfilewr);
			if (rd || wr)
			{
				ubyte[] fbuf = cast(ubyte[])std.file.read(f.name);
				string cbuf;
				// strip BOM from all but the first file
				if(fbuf.length > 1 && fbuf[0] == 0xFF && fbuf[1] == 0xFE)
					cbuf = to!(string)(cast(wstring)(fbuf[2..$]));
				else
					cbuf = cast(string)fbuf;
				if(rd)
					rdbuf ~= cbuf;
				else
					wrbuf ~= cbuf;
			}
		}
		string[] rdlines = splitLines(rdbuf, KeepTerminator.yes);
		string[] wrlines = splitLines(wrbuf, KeepTerminator.yes);
		bool[string] wrset;
		foreach(w; wrlines)
			wrset[w] = true;

		string buf;
		foreach(r; rdlines)
			if(r !in wrset)
				buf ~= r;

		std.file.write(depsfile, buf);
	}

	return exitCode;
}

int runProcess(string command, string depsfile, bool doDemangle, bool demangleAll, bool gdcMode, bool msMode)
{
	HANDLE hStdOutRead;
	HANDLE hStdOutWrite;
	HANDLE hStdInRead;
	HANDLE hStdInWrite;

	SECURITY_ATTRIBUTES saAttr;

	// Set the bInheritHandle flag so pipe handles are inherited.

	saAttr.nLength = SECURITY_ATTRIBUTES.sizeof;
	saAttr.bInheritHandle = TRUE;
	saAttr.lpSecurityDescriptor = null;

	// Create a pipe for the child process's STDOUT.

	if ( ! CreatePipe(&hStdOutRead, &hStdOutWrite, &saAttr, 0) )
		assert(0);

	// Ensure the read handle to the pipe for STDOUT is not inherited.

	if ( ! SetHandleInformation(hStdOutRead, HANDLE_FLAG_INHERIT, 0) )
		assert(0);

	if ( ! CreatePipe(&hStdInRead, &hStdInWrite, &saAttr, 0) )
		assert(0);

	if ( ! SetHandleInformation(hStdInWrite, HANDLE_FLAG_INHERIT, 0) )
		assert(0);

	PROCESS_INFORMATION piProcInfo;
	STARTUPINFOA siStartInfo;
	BOOL bSuccess = FALSE;

	// Set up members of the PROCESS_INFORMATION structure.

	memset( &piProcInfo, 0, PROCESS_INFORMATION.sizeof );

	// Set up members of the STARTUPINFO structure.
	// This structure specifies the STDIN and STDOUT handles for redirection.

	memset( &siStartInfo, 0, STARTUPINFOA.sizeof );
	siStartInfo.cb = STARTUPINFOA.sizeof;
	siStartInfo.hStdError = hStdOutWrite;
	siStartInfo.hStdOutput = hStdOutWrite;
	siStartInfo.hStdInput = hStdInRead;
	siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

	int cp = GetKBCodePage();
	auto szCommand = toMBSz(command, cp);
	bSuccess = CreateProcessA(null,
							  cast(char*)szCommand,     // command line
							  null,          // process security attributes
							  null,          // primary thread security attributes
							  TRUE,          // handles are inherited
							  CREATE_SUSPENDED,             // creation flags
							  null,          // use parent's environment
							  null,          // use parent's current directory
							  &siStartInfo,  // STARTUPINFO pointer
							  &piProcInfo);  // receives PROCESS_INFORMATION

	if(!bSuccess)
	{
		printf("failed launching %s\n", szCommand);
		return 1;
	}

	if(depsfile)
		InjectDLL(piProcInfo.hProcess, depsfile);
	ResumeThread(piProcInfo.hThread);

	char[] buffer = new char[2048];
	DWORD bytesRead = 0;
	DWORD bytesAvaiable = 0;
	DWORD exitCode = 0;
	bool linkerFound = gdcMode || msMode || demangleAll;

	while(true)
	{
		bSuccess = PeekNamedPipe(hStdOutRead, buffer.ptr, buffer.length, &bytesRead, &bytesAvaiable, null);
		if(bSuccess && bytesAvaiable > 0)
		{
			size_t lineLength = 0;
			for(; lineLength < buffer.length && lineLength < bytesAvaiable && buffer[lineLength] != '\n'; lineLength++){}
			if(lineLength >= bytesAvaiable)
			{
				// if no line end found, retry with larger buffer
				if(lineLength >= buffer.length)
					buffer.length = buffer.length * 2;
				continue;
			}
			bSuccess = ReadFile(hStdOutRead, buffer.ptr, lineLength+1, &bytesRead, null);
			if(!bSuccess || bytesRead == 0)
				break;

			demangleLine(buffer[0 .. bytesRead], doDemangle, demangleAll, msMode, gdcMode, cp, linkerFound);
		}
		else
		{
			bSuccess = GetExitCodeProcess(piProcInfo.hProcess, &exitCode);
			if(!bSuccess || exitCode != 259) //259 == STILL_ACTIVE
				break;
			Sleep(5);
		}
	}

	//close the handles to the process
	CloseHandle(hStdInWrite);
	CloseHandle(hStdOutRead);
	CloseHandle(piProcInfo.hProcess);
	CloseHandle(piProcInfo.hThread);

	return exitCode;
}

void demangleLine(char[] output, bool doDemangle, bool demangleAll, bool msMode, bool gdcMode, int cp, ref bool linkerFound)
{
	if (output.length && output[$-1] == '\n')  //remove trailing \n
		output = output[0 .. $-1];
	while(output.length && output[$-1] == '\r')  //remove trailing \r
		output = output[0 .. $-1];

	while(output.length && output[0] == '\r') // remove preceding \r
		output = output[1 .. $];

	if(msMode) //the microsoft linker outputs the error messages in the default ANSI codepage so we need to convert it to UTF-8
	{
		static WCHAR[] decodeBufferWide;
		static char[] decodeBuffer;

		if(decodeBufferWide.length < output.length + 1)
		{
			decodeBufferWide.length = output.length + 1;
			decodeBuffer.length = 2 * output.length + 1;
		}
		auto numDecoded = MultiByteToWideChar(CP_ACP, 0, output.ptr, output.length, decodeBufferWide.ptr, decodeBufferWide.length);
		auto numEncoded = WideCharToMultiByte(CP_UTF8, 0, decodeBufferWide.ptr, numDecoded, decodeBuffer.ptr, decodeBuffer.length, null, null);
		output = decodeBuffer[0..numEncoded];
	}
	size_t writepos = 0;

	if(!linkerFound)
	{
		if (output.startsWith("OPTLINK (R)"))
			linkerFound = true;
		else if(output.countUntil("error LNK") >= 0 || output.countUntil("warning LNK") >= 0)
			linkerFound = msMode = true;
	}

	if(doDemangle && linkerFound)
	{
		if(gdcMode)
		{
			if(demangleAll || output.countUntil("undefined reference to") >= 0 || output.countUntil("In function") >= 0)
			{
				processLine(output, writepos, false, cp);
			}
		}
		else if(msMode)
		{
			if(demangleAll || output.countUntil("LNK") >= 0)
			{
				processLine(output, writepos, false, cp);
			}
		}
		else
		{
			processLine(output, writepos, true, cp);
		}
	}
	if(writepos < output.length)
		fwrite(output.ptr + writepos, output.length - writepos, 1, stdout);
	fputc('\n', stdout);
}

void processLine(char[] output, ref size_t writepos, bool optlink, int cp)
{
	for(int p = 0; p < output.length; p++)
	{
		if(isIdentifierChar(output[p]))
		{
			int q = p;
			while(p < output.length && isIdentifierChar(output[p]))
				p++;

			auto symbolName = output[q..p];
			const(char)[] realSymbolName = symbolName;
			if(optlink)
			{
				size_t pos = 0;
				realSymbolName = decodeDmdString(symbolName, pos);
				if(pos != p - q)
				{
					// could not decode, might contain UTF8 elements, so try translating to the current code page
					// (demangling will not work anyway)
					try
					{
						auto szName = toMBSz(symbolName, cp);
						auto plen = strlen(szName);
						realSymbolName = szName[0..plen];
						pos = p - q;
					}
					catch(Exception)
					{
						realSymbolName = null;
					}
				}
			}
			if(realSymbolName.length)
			{
				if(realSymbolName != symbolName)
				{
					// not sure if output is UTF8 encoded, so avoid any translation
					if(q > writepos)
						fwrite(output.ptr + writepos, q - writepos, 1, stdout);
					fwrite(realSymbolName.ptr, realSymbolName.length, 1, stdout);
					writepos = p;
				}
				while(realSymbolName.length > 1 && realSymbolName[0] == '_')
					realSymbolName = realSymbolName[1..$];
				if(realSymbolName.length > 2 && realSymbolName[0] == 'D' && isDigit(realSymbolName[1]))
				{
					try
					{
						symbolName = demangle(realSymbolName);
					}
					catch(Exception)
					{
					}
					if(realSymbolName != symbolName)
					{
						// skip a trailing quote
						if(p + 1 < output.length && (output[p+1] == '\'' || output[p+1] == '\"'))
							p++;
						if(p > writepos)
							fwrite(output.ptr + writepos, p - writepos, 1, stdout);
						writepos = p;
						fwrite(" (".ptr, 2, 1, stdout);
						fwrite(symbolName.ptr, symbolName.length, 1, stdout);
						fwrite(")".ptr, 1, 1, stdout);
					}
				}
			}
		}
	}
}

///////////////////////////////////////////////////////////////////////////////
bool isExe64bit(string exe)
//out(res) { 	printf("isExe64bit: %.*s %d-bit\n", exe.length, exe.ptr, res ? 64 : 32); }
body
{
	if (exe is null || !std.file.exists(exe))
		return false;

	try
	{
		File f = File(exe, "rb");
		IMAGE_DOS_HEADER dosHdr;
		f.rawRead((&dosHdr)[0..1]);
		if (dosHdr.e_magic != IMAGE_DOS_SIGNATURE)
			return false;
		f.seek(dosHdr.e_lfanew);
		IMAGE_NT_HEADERS ntHdr;
		f.rawRead((&ntHdr)[0..1]);
		return ntHdr.FileHeader.Machine == IMAGE_FILE_MACHINE_AMD64
			|| ntHdr.FileHeader.Machine == IMAGE_FILE_MACHINE_IA64;
	}
	catch(Exception)
	{
	}
	return false;
}

string findExeInPath(string exe)
{
	if (std.path.baseName(exe) != exe)
		return exe; // if the file has dir component, don't search path

	string path = std.process.environment["PATH"];
	string[] paths = split(path, ";");
	string ext = extension(exe);

	foreach(p; paths)
	{
		if (p.length > 0 && p[0] == '"' && p[$-1] == '"') // remove quotes
			p = p[1 .. $-1];
		p = std.path.buildPath(p, exe);
		if(std.file.exists(p))
			return p;

		if (ext.empty)
		{
			if(std.file.exists(p ~ ".exe"))
				return p ~ ".exe";
			if(std.file.exists(p ~ ".com"))
				return p ~ ".com";
			if(std.file.exists(p ~ ".bat"))
				return p ~ ".bat";
			if(std.file.exists(p ~ ".cmd"))
				return p ~ ".cmd";
		}
	}
	return null;
}

enum SECURE_ACCESS = ~(WRITE_DAC | WRITE_OWNER | GENERIC_ALL | ACCESS_SYSTEM_SECURITY);
enum KEY_WOW64_32KEY = 0x200;
enum KEY_WOW64_64KEY = 0x100;

string findTracker(bool x64)
{
	string exe = findExeInPath("tracker.exe");
	if (!exe.empty && isExe64bit(exe) != x64)
		exe = null;

	if (exe.empty)
		exe = findTrackerInMSBuild (r"SOFTWARE\Microsoft\MSBuild\ToolsVersions\12.0"w.ptr, x64);
	if (exe.empty)
		exe = findTrackerInMSBuild (r"SOFTWARE\Microsoft\MSBuild\ToolsVersions\11.0"w.ptr, x64);
	if (exe.empty)
		exe = findTrackerInMSBuild (r"SOFTWARE\Microsoft\MSBuild\ToolsVersions\10.0"w.ptr, x64);
	if (exe.empty)
		exe = findTrackerInSDK(x64);
	return exe;
}

string trackerPath(string binpath, bool x64)
{
	if (binpath.empty)
		return null;
	string exe = buildPath(binpath, "tracker.exe");
	//printf("trying %.*s\n", exe.length, exe.ptr);
	if (!std.file.exists(exe))
		return null;
	if (isExe64bit(exe) != x64)
		return null;
	return exe;
}

string findTrackerInMSBuild (const(wchar)* keyname, bool x64)
{
	string path = readRegistry(keyname, "MSBuildToolsPath"w.ptr, x64);
	return trackerPath(path, x64);
}

string findTrackerInSDK (bool x64)
{
	wstring suffix = x64 ? "-x64" : "-x86";
	wstring sdk = r"SOFTWARE\Microsoft\Microsoft SDKs\Windows";
	HKEY key;
	LONG lRes = RegOpenKeyExW(HKEY_LOCAL_MACHINE, sdk.ptr, 0,
							  KEY_READ | KEY_WOW64_32KEY, &key); // always in Wow6432
	if (lRes != ERROR_SUCCESS)
		return null;

	string exe;
	DWORD idx = 0;
	wchar[100] ver;
	DWORD len = ver.length;
	while (RegEnumKeyExW(key, idx, ver.ptr, &len, null, null, null, null) == ERROR_SUCCESS)
	{
		const(wchar)[] sdkver = sdk ~ r"\"w ~ ver[0..len];
		const(wchar)* wsdkver = toUTF16z(sdkver);
		HKEY verkey;
		lRes = RegOpenKeyExW(HKEY_LOCAL_MACHINE, wsdkver, 0, KEY_READ | KEY_WOW64_32KEY, &verkey); // always in Wow6432
		if (lRes == ERROR_SUCCESS)
		{
			DWORD veridx = 0;
			wchar[100] sub;
			len = sub.length;
			while (RegEnumKeyExW(verkey, veridx, sub.ptr, &len, null, null, null, null) == ERROR_SUCCESS)
			{
				const(wchar)[] sdkversub = sdkver ~ r"\"w ~ sub[0..len];
				string path = readRegistry(toUTF16z(sdkversub), "InstallationFolder"w.ptr, false);
				exe = trackerPath(path, x64);
				if (!exe.empty)
					break;
				veridx++;
			}
			RegCloseKey(verkey);
		}
		idx++;
		if (!exe.empty)
			break;
	}
	RegCloseKey(key);

	return exe;
}

string readRegistry(const(wchar)* keyname, const(wchar)* valname, bool x64)
{
	string path;
	HKEY key;
	LONG lRes = RegOpenKeyExW(HKEY_LOCAL_MACHINE, keyname, 0,
							  KEY_READ | (x64 ? KEY_WOW64_64KEY : KEY_WOW64_32KEY), &key);
	//printf("RegOpenKeyExW = %d, key=%x\n", lRes, key);
	if (lRes == ERROR_SUCCESS)
	{
		DWORD type;
		DWORD cntBytes;
		int hr = RegQueryValueExW(key, valname, null, &type, null, &cntBytes);
		//printf("RegQueryValueW = %d, %d words\n", hr, cntBytes);
		if (hr == ERROR_SUCCESS || hr == ERROR_MORE_DATA)
		{
			wchar[] wpath = new wchar[(cntBytes + 1) / 2];
			hr = RegQueryValueExW(key, valname, null, &type, wpath.ptr, &cntBytes);
			if (hr == ERROR_SUCCESS)
				path = toUTF8(wpath[0..$-1]); // strip trailing 0
		}
		RegCloseKey(key);
	}
	return path;
}

///////////////////////////////////////////////////////////////////////////////
// inject DLL into linker process to monitor file reads

alias extern(Windows) DWORD function(LPVOID lpThreadParameter) LPTHREAD_START_ROUTINE;
extern(Windows) BOOL
WriteProcessMemory(HANDLE hProcess, LPVOID lpBaseAddress, LPCVOID lpBuffer, SIZE_T nSize, SIZE_T * lpNumberOfBytesWritten);
extern(Windows) HANDLE
CreateRemoteThread(HANDLE hProcess, LPSECURITY_ATTRIBUTES lpThreadAttributes, SIZE_T dwStackSize,
				   LPTHREAD_START_ROUTINE lpStartAddress, LPVOID lpParameter, DWORD dwCreationFlags, LPDWORD lpThreadId);

void InjectDLL(HANDLE hProcess, string depsfile)
{
	HANDLE hThread, hRemoteModule;

	HMODULE appmod = GetModuleHandleA(null);
	wchar[] wmodname = new wchar[260];
	DWORD len = GetModuleFileNameW(appmod, wmodname.ptr, wmodname.length);
	if(len > wmodname.length)
	{
		wmodname = new wchar[len + 1];
		GetModuleFileNameW(null, wmodname.ptr, len + 1);
	}
	string modpath = to!string(wmodname);
	string dll = buildPath(std.path.dirName(modpath), "filemonitor.dll");

	auto wdll = to!wstring(dll) ~ cast(wchar)0;
	// detect offset of dumpFile
	HMODULE fmod = LoadLibraryW(wdll.ptr);
	if(!fmod)
		return;
	size_t addr = cast(size_t)GetProcAddress(fmod, "_D11filemonitor8dumpFileG260a");
	FreeLibrary(fmod);
	if(addr == 0)
		return;
	addr = addr - cast(size_t)fmod;

	// copy path to other process
	auto wdllRemote = VirtualAllocEx(hProcess, null, wdll.length * 2, MEM_COMMIT, PAGE_READWRITE);
	auto procWrite = getWriteProcFunc();
	procWrite(hProcess, wdllRemote, wdll.ptr, wdll.length * 2, null);

	// load dll into other process, assuming LoadLibraryW is at the same address in all processes
	HMODULE mod = GetModuleHandleA("Kernel32");
	auto proc = GetProcAddress(mod, "LoadLibraryW");
	hThread = getCreateRemoteThreadFunc()(hProcess, null, 0, cast(LPTHREAD_START_ROUTINE)proc, wdllRemote, 0, null);
	WaitForSingleObject(hThread, INFINITE);

	// Get handle of the loaded module
	GetExitCodeThread(hThread, cast(DWORD*) &hRemoteModule);

	// Clean up
	CloseHandle(hThread);
	VirtualFreeEx(hProcess, wdllRemote, wdll.length * 2, MEM_RELEASE);

	void* pDumpFile = cast(char*)hRemoteModule + addr;
	// printf("remotemod = %p, addr = %p\n", hRemoteModule, pDumpFile);
	auto szDepsFile = toMBSz(depsfile);

	procWrite(hProcess, pDumpFile, szDepsFile, strlen(szDepsFile) + 1, null);
}

typeof(WriteProcessMemory)* getWriteProcFunc ()
{
	HMODULE mod = GetModuleHandleA("Kernel32");
	auto proc = GetProcAddress(mod, "WriteProcessMemory");
	return cast(typeof(WriteProcessMemory)*)proc;
}

typeof(CreateRemoteThread)* getCreateRemoteThreadFunc ()
{
	HMODULE mod = GetModuleHandleA("Kernel32");
	auto proc = GetProcAddress(mod, "CreateRemoteThread");
	return cast(typeof(CreateRemoteThread)*)proc;
}

///////////////////////////////////////////////////////////////////////////////
extern(C)
{
	struct PROCESS_INFORMATION
	{
		HANDLE hProcess;
		HANDLE hThread;
		DWORD dwProcessId;
		DWORD dwThreadId;
	}

	alias PROCESS_INFORMATION* LPPROCESS_INFORMATION;

	struct STARTUPINFOA
	{
		DWORD   cb;
		LPSTR   lpReserved;
		LPSTR   lpDesktop;
		LPSTR   lpTitle;
		DWORD   dwX;
		DWORD   dwY;
		DWORD   dwXSize;
		DWORD   dwYSize;
		DWORD   dwXCountChars;
		DWORD   dwYCountChars;
		DWORD   dwFillAttribute;
		DWORD   dwFlags;
		WORD    wShowWindow;
		WORD    cbReserved2;
		LPBYTE  lpReserved2;
		HANDLE  hStdInput;
		HANDLE  hStdOutput;
		HANDLE  hStdError;
	}

	alias STARTUPINFOA* LPSTARTUPINFOA;

	enum
	{
		CP_ACP                   = 0,
		CP_OEMCP                 = 1,
		CP_MACCP                 = 2,
		CP_THREAD_ACP            = 3,
		CP_SYMBOL                = 42,
		CP_UTF7                  = 65000,
		CP_UTF8                  = 65001
	}

	enum IMAGE_DOS_SIGNATURE = 0x5A4D;      // MZ

	struct IMAGE_DOS_HEADER       // DOS .EXE header
	{
		WORD   e_magic;                     // Magic number
		WORD   e_cblp;                      // Bytes on last page of file
		WORD   e_cp;                        // Pages in file
		WORD   e_crlc;                      // Relocations
		WORD   e_cparhdr;                   // Size of header in paragraphs
		WORD   e_minalloc;                  // Minimum extra paragraphs needed
		WORD   e_maxalloc;                  // Maximum extra paragraphs needed
		WORD   e_ss;                        // Initial (relative) SS value
		WORD   e_sp;                        // Initial SP value
		WORD   e_csum;                      // Checksum
		WORD   e_ip;                        // Initial IP value
		WORD   e_cs;                        // Initial (relative) CS value
		WORD   e_lfarlc;                    // File address of relocation table
		WORD   e_ovno;                      // Overlay number
		WORD   e_res[4];                    // Reserved words
		WORD   e_oemid;                     // OEM identifier (for e_oeminfo)
		WORD   e_oeminfo;                   // OEM information; e_oemid specific
		WORD   e_res2[10];                  // Reserved words
		LONG   e_lfanew;                    // File address of new exe header
	}

	struct IMAGE_NT_HEADERS
	{
		DWORD Signature;
		IMAGE_FILE_HEADER FileHeader;
		// IMAGE_OPTIONAL_HEADER32 OptionalHeader;
	}

	enum IMAGE_FILE_MACHINE_IA64  = 0x0200;  // Intel 64
	enum IMAGE_FILE_MACHINE_AMD64 = 0x8664;  // AMD64 (K8)

	struct IMAGE_FILE_HEADER
	{
		WORD    Machine;
		WORD    NumberOfSections;
		DWORD   TimeDateStamp;
		DWORD   PointerToSymbolTable;
		DWORD   NumberOfSymbols;
		WORD    SizeOfOptionalHeader;
		WORD    Characteristics;
	}
}

extern(System)
{
	BOOL CreatePipe(HANDLE* hReadPipe,
					HANDLE* hWritePipe,
					SECURITY_ATTRIBUTES* lpPipeAttributes,
					DWORD nSize);

	BOOL SetHandleInformation(HANDLE hObject,
							  DWORD dwMask,
							  DWORD dwFlags);

	BOOL CreateProcessA(LPCSTR lpApplicationName,
						LPSTR lpCommandLine,
						LPSECURITY_ATTRIBUTES lpProcessAttributes,
						LPSECURITY_ATTRIBUTES lpThreadAttributes,
						BOOL bInheritHandles,
						DWORD dwCreationFlags,
						LPVOID lpEnvironment,
						LPCSTR lpCurrentDirectory,
						LPSTARTUPINFOA lpStartupInfo,
						LPPROCESS_INFORMATION lpProcessInformation);

	BOOL GetExitCodeProcess(HANDLE hProcess,
							LPDWORD lpExitCode);

	BOOL PeekNamedPipe(HANDLE hNamedPipe,
					   LPVOID lpBuffer,
					   DWORD nBufferSize,
					   LPDWORD lpBytesRead,
					   LPDWORD lpTotalBytesAvail,
					   LPDWORD lpBytesLeftThisMessage);

	UINT GetKBCodePage();
}

enum uint HANDLE_FLAG_INHERIT = 0x00000001;
enum uint HANDLE_FLAG_PROTECT_FROM_CLOSE = 0x00000002;

enum uint STARTF_USESHOWWINDOW  =  0x00000001;
enum uint STARTF_USESIZE        =  0x00000002;
enum uint STARTF_USEPOSITION    =  0x00000004;
enum uint STARTF_USECOUNTCHARS  =  0x00000008;
enum uint STARTF_USEFILLATTRIBUTE = 0x00000010;
enum uint STARTF_RUNFULLSCREEN   = 0x00000020;  // ignored for non-x86 platforms
enum uint STARTF_FORCEONFEEDBACK = 0x00000040;
enum uint STARTF_FORCEOFFFEEDBACK = 0x00000080;
enum uint STARTF_USESTDHANDLES   = 0x00000100;

enum uint CREATE_SUSPENDED = 0x00000004;
