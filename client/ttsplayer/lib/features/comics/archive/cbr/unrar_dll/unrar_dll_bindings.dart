// ignore_for_file: constant_identifier_names, camel_case_types

import 'package:ffi/ffi.dart';

import 'dart:ffi';

/// Native library filename beside [Platform.resolvedExecutable] on Windows x64.
const unrar64DllFileName = 'UnRAR64.dll';

const int ERAR_SUCCESS = 0;
const int ERAR_END_ARCHIVE = 10;
const int ERAR_NO_MEMORY = 11;
const int ERAR_BAD_DATA = 12;
const int ERAR_BAD_ARCHIVE = 13;
const int ERAR_UNKNOWN_FORMAT = 14;
const int ERAR_EOPEN = 15;
const int ERAR_ECREATE = 16;
const int ERAR_ECLOSE = 17;
const int ERAR_EREAD = 18;
const int ERAR_EWRITE = 19;
const int ERAR_SMALL_BUF = 20;
const int ERAR_UNKNOWN = 21;
const int ERAR_MISSING_PASSWORD = 22;
const int ERAR_EREFERENCE = 23;
const int ERAR_BAD_PASSWORD = 24;
const int ERAR_LARGE_DICT = 25;

const int RAR_OM_LIST = 0;
const int RAR_OM_EXTRACT = 1;

const int RAR_SKIP = 0;
const int RAR_TEST = 1;
const int RAR_EXTRACT = 2;

const int RAR_VOL_ASK = 0;
const int RAR_VOL_NOTIFY = 1;

const int RAR_DLL_VERSION = 10;

const int RHDF_SPLITBEFORE = 0x01;
const int RHDF_SPLITAFTER = 0x02;
const int RHDF_ENCRYPTED = 0x04;
const int RHDF_SOLID = 0x10;
const int RHDF_DIRECTORY = 0x20;

const int ROADF_VOLUME = 0x0001;
const int ROADF_FIRSTVOLUME = 0x0100;

const int UCM_CHANGEVOLUME = 0;
const int UCM_PROCESSDATA = 1;
const int UCM_NEEDPASSWORD = 2;
const int UCM_CHANGEVOLUMEW = 3;
const int UCM_NEEDPASSWORDW = 4;
const int UCM_LARGEDICT = 5;

typedef UNRARCALLBACKNative = Int32 Function(
  Uint32 msg,
  IntPtr userData,
  IntPtr p1,
  IntPtr p2,
);
typedef UNRARCALLBACKDart = int Function(
  int msg,
  int userData,
  int p1,
  int p2,
);

@Packed(1)
final class RAROpenArchiveDataEx extends Struct {
  external Pointer<Utf8> ArcName;
  external Pointer<Uint16> ArcNameW;
  @Uint32()
  external int OpenMode;
  @Uint32()
  external int OpenResult;
  external Pointer<Utf8> CmtBuf;
  @Uint32()
  external int CmtBufSize;
  @Uint32()
  external int CmtSize;
  @Uint32()
  external int CmtState;
  @Uint32()
  external int Flags;
  external Pointer<NativeFunction<UNRARCALLBACKNative>> Callback;
  @IntPtr()
  external int UserData;
  @Uint32()
  external int OpFlags;
  external Pointer<Uint16> CmtBufW;
  external Pointer<Uint16> MarkOfTheWeb;
  @Array(23)
  external Array<Uint32> Reserved;
}

@Packed(1)
final class RARHeaderDataEx extends Struct {
  @Array(1024)
  external Array<Int8> ArcName;
  @Array(1024)
  external Array<Uint16> ArcNameW;
  @Array(1024)
  external Array<Int8> FileName;
  @Array(1024)
  external Array<Uint16> FileNameW;
  @Uint32()
  external int Flags;
  @Uint32()
  external int PackSize;
  @Uint32()
  external int PackSizeHigh;
  @Uint32()
  external int UnpSize;
  @Uint32()
  external int UnpSizeHigh;
  @Uint32()
  external int HostOS;
  @Uint32()
  external int FileCRC;
  @Uint32()
  external int FileTime;
  @Uint32()
  external int UnpVer;
  @Uint32()
  external int Method;
  @Uint32()
  external int FileAttr;
  external Pointer<Utf8> CmtBuf;
  @Uint32()
  external int CmtBufSize;
  @Uint32()
  external int CmtSize;
  @Uint32()
  external int CmtState;
  @Uint32()
  external int DictSize;
  @Uint32()
  external int HashType;
  @Array(32)
  external Array<Int8> Hash;
  @Uint32()
  external int RedirType;
  external Pointer<Uint16> RedirName;
  @Uint32()
  external int RedirNameSize;
  @Uint32()
  external int DirTarget;
  @Uint32()
  external int MtimeLow;
  @Uint32()
  external int MtimeHigh;
  @Uint32()
  external int CtimeLow;
  @Uint32()
  external int CtimeHigh;
  @Uint32()
  external int AtimeLow;
  @Uint32()
  external int AtimeHigh;
  external Pointer<Uint16> ArcNameEx;
  @Uint32()
  external int ArcNameExSize;
  external Pointer<Uint16> FileNameEx;
  @Uint32()
  external int FileNameExSize;
  @Array(982)
  external Array<Uint32> Reserved;
}

/// Required exported symbols for Gate 1 verification.
const unrarRequiredExports = <String>[
  'RAROpenArchiveEx',
  'RARCloseArchive',
  'RARReadHeaderEx',
  'RARProcessFile',
  'RARGetDllVersion',
];
