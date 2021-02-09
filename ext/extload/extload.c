
#include <windows.h>
#include <string.h>
#include <stdio.h>

static TCHAR  szModulePath[MAX_PATH+1] = {0};
static TCHAR *pszPathEnd = 0;

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
  (void)lpvReserved;
  size_t len;

  if (fdwReason == DLL_PROCESS_ATTACH)
  {
    GetModuleFileName(hinstDLL, &szModulePath[0], MAX_PATH);
    /* find last path separator and cut off path to get foldername incl. last separator */
    len = strlen (&szModulePath[0]);
    while (len > 0 && szModulePath[--len] != '\\') ;
    pszPathEnd = &szModulePath[len+1];
    *pszPathEnd = '\0';
  }
  return TRUE;
}

typedef void (WINAPI *TExtInit)(void);

#define DEF_EXTENSION_INIT(LIBNAME) \
__declspec (dllexport) void Init_ ## LIBNAME ## w() \
{ \
  const char *pszLibName; \
  HMODULE hlib; \
  TExtInit pfInit; \
\
  pszLibName = #LIBNAME ".so"; \
  strcat (&szModulePath[0], pszLibName); \
  if (NULL == (hlib = LoadLibraryEx(szModulePath, NULL, LOAD_WITH_ALTERED_SEARCH_PATH))) \
  { \
    *pszPathEnd = '\0'; \
    strcat (&szModulePath[0], #LIBNAME "\\"); \
    strcat (&szModulePath[0], pszLibName); \
    if (NULL == (hlib = LoadLibraryEx(szModulePath, NULL, LOAD_WITH_ALTERED_SEARCH_PATH))) \
    { \
      DWORD dwError = GetLastError(); \
      printf("ERROR: extload failed to load %s.so and %s, error code %lu\n", #LIBNAME, szModulePath, dwError); \
      return; \
    } \
  } \
  if (NULL == (pfInit = (TExtInit) GetProcAddress(hlib, "Init_" #LIBNAME))) \
  { \
    printf("ERROR: extload failed to retrieve init proc %s from lib %s\n", "Init_" #LIBNAME, #LIBNAME); \
    return; \
  } \
  pfInit (); \
}

DEF_EXTENSION_INIT(libr2tao)

DEF_EXTENSION_INIT(librpoa)

DEF_EXTENSION_INIT(librpol)
