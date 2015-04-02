/*
 * FPGA Interface C API 13.0 source file.
 *
 * Copyright (c) 2013,
 * National Instruments Corporation.
 * All rights reserved.
 */

#include "NiFpga.h"

/*
 * Platform specific includes.
 */
#if NiFpga_Windows
   #include <windows.h>
#elif NiFpga_VxWorks
   #include <vxWorks.h>
   #include <symLib.h>
   #include <loadLib.h>
   #include <sysSymTbl.h>
   MODULE_ID VxLoadLibraryFromPath(const char* path, int flags);
   STATUS VxFreeLibrary(MODULE_ID library, int flags);
#elif NiFpga_Linux
   #include <stdlib.h>
   #include <stdio.h>
   #include <dlfcn.h>
#else
   #error
#endif

/*
 * Platform specific defines.
 */
#if NiFpga_Windows
   #define NiFpga_CCall   __cdecl
   #define NiFpga_StdCall __stdcall
#else
   #define NiFpga_CCall
   #define NiFpga_StdCall
#endif

/*
 * Global library handle, or NULL if the library isn't loaded.
 */
#if NiFpga_Windows
   static HMODULE NiFpga_library = NULL;
#elif NiFpga_VxWorks
   static MODULE_ID NiFpga_library = NULL;
#elif NiFpga_Linux
   static void* NiFpga_library = NULL;
#else
   #error
#endif

/*
 * CVI Resource Tracking functions.
 */
#if NiFpga_Cvi && NiFpga_Windows
#define NiFpga_CviResourceTracking 1

static char* const NiFpga_cviResourceType = "FPGA Interface C API";

typedef void* (NiFpga_CCall *NiFpga_AcquireCviResource)(void* resource,
                                                        char* type,
                                                        char* description,
                                                        ...);

static NiFpga_AcquireCviResource NiFpga_acquireCviResource = NULL;

typedef void* (NiFpga_StdCall *NiFpga_ReleaseCviResource)(void* resource);

static NiFpga_ReleaseCviResource NiFpga_releaseCviResource = NULL;
#endif

/*
 * Session management functions.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_open)(
                          const char*     path,
                          const char*     signature,
                          const char*     resource,
                          uint32_t        attribute,
                          NiFpga_Session* session) = NULL;

NiFpga_Status NiFpga_Open(const char*     path,
                          const char*     signature,
                          const char*     resource,
                          uint32_t        attribute,
                          NiFpga_Session* session)
{
   const NiFpga_Status result = NiFpga_open
                              ? NiFpga_open(path,
                                            signature,
                                            resource,
                                            attribute,
                                            session)
                              : NiFpga_Status_ResourceNotInitialized;
   #if NiFpga_CviResourceTracking
      if (NiFpga_acquireCviResource
      &&  NiFpga_IsNotError(result))
         NiFpga_acquireCviResource((void*)*session,
                                   NiFpga_cviResourceType,
                                   "NiFpga_Session %#08x",
                                   *session);
   #endif
   return result;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_close)(
                           NiFpga_Session session,
                           uint32_t       attribute) = NULL;

NiFpga_Status NiFpga_Close(NiFpga_Session session,
                           uint32_t       attribute)
{
   if (!NiFpga_close)
      return NiFpga_Status_ResourceNotInitialized;
   #if NiFpga_CviResourceTracking
      if (NiFpga_releaseCviResource)
         NiFpga_releaseCviResource((void*)session);
   #endif
   return NiFpga_close(session, attribute);
}

/*
 * FPGA state functions.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_run)(
                         NiFpga_Session session,
                         uint32_t       attribute) = NULL;

NiFpga_Status NiFpga_Run(NiFpga_Session session,
                         uint32_t       attribute)
{
   return NiFpga_run
        ? NiFpga_run(session, attribute)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_abort)(
                           NiFpga_Session session) = NULL;

NiFpga_Status NiFpga_Abort(NiFpga_Session session)
{
   return NiFpga_abort
        ? NiFpga_abort(session)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_reset)(
                           NiFpga_Session session) = NULL;

NiFpga_Status NiFpga_Reset(NiFpga_Session session)
{
   return NiFpga_reset
        ? NiFpga_reset(session)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_download)(
                              NiFpga_Session session) = NULL;

NiFpga_Status NiFpga_Download(NiFpga_Session session)
{
   return NiFpga_download
        ? NiFpga_download(session)
        : NiFpga_Status_ResourceNotInitialized;
}

/*
 * Functions to read from scalar indicators and controls.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_readBool)(
                              NiFpga_Session session,
                              uint32_t       indicator,
                              NiFpga_Bool*   value) = NULL;

NiFpga_Status NiFpga_ReadBool(NiFpga_Session session,
                              uint32_t       indicator,
                              NiFpga_Bool*   value)
{
   return NiFpga_readBool
        ? NiFpga_readBool(session, indicator, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readI8)(
                            NiFpga_Session session,
                            uint32_t       indicator,
                            int8_t*        value) = NULL;

NiFpga_Status NiFpga_ReadI8(NiFpga_Session session,
                            uint32_t       indicator,
                            int8_t*        value)
{
   return NiFpga_readI8
        ? NiFpga_readI8(session, indicator, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readU8)(
                            NiFpga_Session session,
                            uint32_t       indicator,
                            uint8_t*       value) = NULL;

NiFpga_Status NiFpga_ReadU8(NiFpga_Session session,
                            uint32_t       indicator,
                            uint8_t*       value)
{
   return NiFpga_readU8
        ? NiFpga_readU8(session, indicator, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readI16)(
                             NiFpga_Session session,
                             uint32_t       indicator,
                             int16_t*       value) = NULL;

NiFpga_Status NiFpga_ReadI16(NiFpga_Session session,
                             uint32_t       indicator,
                             int16_t*       value)
{
   return NiFpga_readI16
        ? NiFpga_readI16(session, indicator, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readU16)(
                             NiFpga_Session session,
                             uint32_t       indicator,
                             uint16_t*      value) = NULL;

NiFpga_Status NiFpga_ReadU16(NiFpga_Session session,
                             uint32_t       indicator,
                             uint16_t*      value)
{
   return NiFpga_readU16
        ? NiFpga_readU16(session, indicator, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readI32)(
                             NiFpga_Session session,
                             uint32_t       indicator,
                             int32_t*       value) = NULL;

NiFpga_Status NiFpga_ReadI32(NiFpga_Session session,
                             uint32_t       indicator,
                             int32_t*       value)
{
   return NiFpga_readI32
        ? NiFpga_readI32(session, indicator, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readU32)(
                             NiFpga_Session session,
                             uint32_t       indicator,
                             uint32_t*      value) = NULL;

NiFpga_Status NiFpga_ReadU32(NiFpga_Session session,
                             uint32_t       indicator,
                             uint32_t*      value)
{
   return NiFpga_readU32
        ? NiFpga_readU32(session, indicator, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readI64)(
                             NiFpga_Session session,
                             uint32_t       indicator,
                             int64_t*       value) = NULL;

NiFpga_Status NiFpga_ReadI64(NiFpga_Session session,
                             uint32_t       indicator,
                             int64_t*       value)
{
   return NiFpga_readI64
        ? NiFpga_readI64(session, indicator, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readU64)(
                             NiFpga_Session session,
                             uint32_t       indicator,
                             uint64_t*      value) = NULL;

NiFpga_Status NiFpga_ReadU64(NiFpga_Session session,
                             uint32_t       indicator,
                             uint64_t*      value)
{
   return NiFpga_readU64
        ? NiFpga_readU64(session, indicator, value)
        : NiFpga_Status_ResourceNotInitialized;
}

/*
 * Functions to write to scalar controls and indicators.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_writeBool)(
                               NiFpga_Session session,
                               uint32_t       control,
                               NiFpga_Bool    value) = NULL;

NiFpga_Status NiFpga_WriteBool(NiFpga_Session session,
                               uint32_t       control,
                               NiFpga_Bool    value)
{
   return NiFpga_writeBool
        ? NiFpga_writeBool(session, control, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeI8)(
                             NiFpga_Session session,
                             uint32_t       control,
                             int8_t         value) = NULL;

NiFpga_Status NiFpga_WriteI8(NiFpga_Session session,
                             uint32_t       control,
                             int8_t         value)
{
   return NiFpga_writeI8
        ? NiFpga_writeI8(session, control, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeU8)(
                             NiFpga_Session session,
                             uint32_t       control,
                             uint8_t        value) = NULL;

NiFpga_Status NiFpga_WriteU8(NiFpga_Session session,
                             uint32_t       control,
                             uint8_t        value)
{
   return NiFpga_writeU8
        ? NiFpga_writeU8(session, control, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeI16)(
                              NiFpga_Session session,
                              uint32_t       control,
                              int16_t        value) = NULL;

NiFpga_Status NiFpga_WriteI16(NiFpga_Session session,
                              uint32_t       control,
                              int16_t        value)
{
   return NiFpga_writeI16
        ? NiFpga_writeI16(session, control, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeU16)(
                              NiFpga_Session session,
                              uint32_t       control,
                              uint16_t       value) = NULL;

NiFpga_Status NiFpga_WriteU16(NiFpga_Session session,
                              uint32_t       control,
                              uint16_t       value)
{
   return NiFpga_writeU16
        ? NiFpga_writeU16(session, control, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeI32)(
                              NiFpga_Session session,
                              uint32_t       control,
                              int32_t        value) = NULL;

NiFpga_Status NiFpga_WriteI32(NiFpga_Session session,
                              uint32_t       control,
                              int32_t        value)
{
   return NiFpga_writeI32
        ? NiFpga_writeI32(session, control, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeU32)(
                              NiFpga_Session session,
                              uint32_t       control,
                              uint32_t       value) = NULL;

NiFpga_Status NiFpga_WriteU32(NiFpga_Session session,
                              uint32_t       control,
                              uint32_t       value)
{
   return NiFpga_writeU32
        ? NiFpga_writeU32(session, control, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeI64)(
                              NiFpga_Session session,
                              uint32_t       control,
                              int64_t        value) = NULL;

NiFpga_Status NiFpga_WriteI64(NiFpga_Session session,
                              uint32_t       control,
                              int64_t        value)
{
   return NiFpga_writeI64
        ? NiFpga_writeI64(session, control, value)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeU64)(
                              NiFpga_Session session,
                              uint32_t       control,
                              uint64_t       value) = NULL;

NiFpga_Status NiFpga_WriteU64(NiFpga_Session session,
                              uint32_t       control,
                              uint64_t       value)
{
   return NiFpga_writeU64
        ? NiFpga_writeU64(session, control, value)
        : NiFpga_Status_ResourceNotInitialized;
}

/*
 * Functions to read from array indicators and controls.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_readArrayBool)(
                                   NiFpga_Session session,
                                   uint32_t       indicator,
                                   NiFpga_Bool*   array,
                                   size_t         size) = NULL;

NiFpga_Status NiFpga_ReadArrayBool(NiFpga_Session session,
                                   uint32_t       indicator,
                                   NiFpga_Bool*   array,
                                   size_t         size)
{
   return NiFpga_readArrayBool
        ? NiFpga_readArrayBool(session, indicator, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readArrayI8)(
                                 NiFpga_Session session,
                                 uint32_t       indicator,
                                 int8_t*        array,
                                 size_t         size) = NULL;

NiFpga_Status NiFpga_ReadArrayI8(NiFpga_Session session,
                                 uint32_t       indicator,
                                 int8_t*        array,
                                 size_t         size)
{
   return NiFpga_readArrayI8
        ? NiFpga_readArrayI8(session, indicator, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readArrayU8)(
                                 NiFpga_Session session,
                                 uint32_t       indicator,
                                 uint8_t*       array,
                                 size_t         size) = NULL;

NiFpga_Status NiFpga_ReadArrayU8(NiFpga_Session session,
                                 uint32_t       indicator,
                                 uint8_t*       array,
                                 size_t         size)
{
   return NiFpga_readArrayU8
        ? NiFpga_readArrayU8(session, indicator, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readArrayI16)(
                                  NiFpga_Session session,
                                  uint32_t       indicator,
                                  int16_t*       array,
                                  size_t         size) = NULL;

NiFpga_Status NiFpga_ReadArrayI16(NiFpga_Session session,
                                  uint32_t       indicator,
                                  int16_t*       array,
                                  size_t         size)
{
   return NiFpga_readArrayI16
        ? NiFpga_readArrayI16(session, indicator, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readArrayU16)(
                                  NiFpga_Session session,
                                  uint32_t       indicator,
                                  uint16_t*      array,
                                  size_t         size) = NULL;

NiFpga_Status NiFpga_ReadArrayU16(NiFpga_Session session,
                                  uint32_t       indicator,
                                  uint16_t*      array,
                                  size_t         size)
{
   return NiFpga_readArrayU16
        ? NiFpga_readArrayU16(session, indicator, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readArrayI32)(
                                  NiFpga_Session session,
                                  uint32_t       indicator,
                                  int32_t*       array,
                                  size_t         size) = NULL;

NiFpga_Status NiFpga_ReadArrayI32(NiFpga_Session session,
                                  uint32_t       indicator,
                                  int32_t*       array,
                                  size_t         size)
{
   return NiFpga_readArrayI32
        ? NiFpga_readArrayI32(session, indicator, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readArrayU32)(
                                  NiFpga_Session session,
                                  uint32_t       indicator,
                                  uint32_t*      array,
                                  size_t         size) = NULL;

NiFpga_Status NiFpga_ReadArrayU32(NiFpga_Session session,
                                  uint32_t       indicator,
                                  uint32_t*      array,
                                  size_t         size)
{
   return NiFpga_readArrayU32
        ? NiFpga_readArrayU32(session, indicator, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readArrayI64)(
                                  NiFpga_Session session,
                                  uint32_t       indicator,
                                  int64_t*       array,
                                  size_t         size) = NULL;

NiFpga_Status NiFpga_ReadArrayI64(NiFpga_Session session,
                                  uint32_t       indicator,
                                  int64_t*       array,
                                  size_t         size)
{
   return NiFpga_readArrayI64
        ? NiFpga_readArrayI64(session, indicator, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readArrayU64)(
                                  NiFpga_Session session,
                                  uint32_t       indicator,
                                  uint64_t*      array,
                                  size_t         size) = NULL;

NiFpga_Status NiFpga_ReadArrayU64(NiFpga_Session session,
                                  uint32_t       indicator,
                                  uint64_t*      array,
                                  size_t         size)
{
   return NiFpga_readArrayU64
        ? NiFpga_readArrayU64(session, indicator, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

/*
 * Functions to write to array controls and indicators.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_writeArrayBool)(
                                    NiFpga_Session     session,
                                    uint32_t           control,
                                    const NiFpga_Bool* array,
                                    size_t             size) = NULL;

NiFpga_Status NiFpga_WriteArrayBool(NiFpga_Session     session,
                                    uint32_t           control,
                                    const NiFpga_Bool* array,
                                    size_t             size)
{
   return NiFpga_writeArrayBool
        ? NiFpga_writeArrayBool(session, control, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeArrayI8)(
                                  NiFpga_Session session,
                                  uint32_t       control,
                                  const int8_t*  array,
                                  size_t         size) = NULL;

NiFpga_Status NiFpga_WriteArrayI8(NiFpga_Session session,
                                  uint32_t       control,
                                  const int8_t*  array,
                                  size_t         size)
{
   return NiFpga_writeArrayI8
        ? NiFpga_writeArrayI8(session, control, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeArrayU8)(
                                  NiFpga_Session session,
                                  uint32_t       control,
                                  const uint8_t* array,
                                  size_t         size) = NULL;

NiFpga_Status NiFpga_WriteArrayU8(NiFpga_Session session,
                                  uint32_t       control,
                                  const uint8_t* array,
                                  size_t         size)
{
   return NiFpga_writeArrayU8
        ? NiFpga_writeArrayU8(session, control, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeArrayI16)(
                                   NiFpga_Session session,
                                   uint32_t       control,
                                   const int16_t* array,
                                   size_t         size) = NULL;

NiFpga_Status NiFpga_WriteArrayI16(NiFpga_Session session,
                                   uint32_t       control,
                                   const int16_t* array,
                                   size_t         size)
{
   return NiFpga_writeArrayI16
        ? NiFpga_writeArrayI16(session, control, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeArrayU16)(
                                   NiFpga_Session  session,
                                   uint32_t        control,
                                   const uint16_t* array,
                                   size_t          size) = NULL;

NiFpga_Status NiFpga_WriteArrayU16(NiFpga_Session  session,
                                   uint32_t        control,
                                   const uint16_t* array,
                                   size_t          size)
{
   return NiFpga_writeArrayU16
        ? NiFpga_writeArrayU16(session, control, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeArrayI32)(
                                   NiFpga_Session session,
                                   uint32_t       control,
                                   const int32_t* array,
                                   size_t         size) = NULL;

NiFpga_Status NiFpga_WriteArrayI32(NiFpga_Session session,
                                   uint32_t       control,
                                   const int32_t* array,
                                   size_t         size)
{
   return NiFpga_writeArrayI32
        ? NiFpga_writeArrayI32(session, control, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeArrayU32)(
                                   NiFpga_Session  session,
                                   uint32_t        control,
                                   const uint32_t* array,
                                   size_t          size) = NULL;

NiFpga_Status NiFpga_WriteArrayU32(NiFpga_Session  session,
                                   uint32_t        control,
                                   const uint32_t* array,
                                   size_t          size)
{
   return NiFpga_writeArrayU32
        ? NiFpga_writeArrayU32(session, control, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeArrayI64)(
                                   NiFpga_Session session,
                                   uint32_t       control,
                                   const int64_t* array,
                                   size_t         size) = NULL;

NiFpga_Status NiFpga_WriteArrayI64(NiFpga_Session session,
                                   uint32_t       control,
                                   const int64_t* array,
                                   size_t         size)
{
   return NiFpga_writeArrayI64
        ? NiFpga_writeArrayI64(session, control, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeArrayU64)(
                                   NiFpga_Session  session,
                                   uint32_t        control,
                                   const uint64_t* array,
                                   size_t          size) = NULL;

NiFpga_Status NiFpga_WriteArrayU64(NiFpga_Session  session,
                                   uint32_t        control,
                                   const uint64_t* array,
                                   size_t          size)
{
   return NiFpga_writeArrayU64
        ? NiFpga_writeArrayU64(session, control, array, size)
        : NiFpga_Status_ResourceNotInitialized;
}

/*
 * Interrupt functions.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_reserveIrqContext)(
                                       NiFpga_Session     session,
                                       NiFpga_IrqContext* context) = NULL;


NiFpga_Status NiFpga_ReserveIrqContext(NiFpga_Session     session,
                                       NiFpga_IrqContext* context)
{
   const NiFpga_Status result = NiFpga_reserveIrqContext
                              ? NiFpga_reserveIrqContext(session, context)
                              : NiFpga_Status_ResourceNotInitialized;
   #if NiFpga_CviResourceTracking
      if (NiFpga_acquireCviResource
      &&  NiFpga_IsNotError(result))
         NiFpga_acquireCviResource(*context,
                                   NiFpga_cviResourceType,
                                   "NiFpga_IrqContext 0x%p",
                                   *context);
   #endif
   return result;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_unreserveIrqContext)(
                                         NiFpga_Session    session,
                                         NiFpga_IrqContext context) = NULL;


NiFpga_Status NiFpga_UnreserveIrqContext(NiFpga_Session    session,
                                         NiFpga_IrqContext context)
{
   if (!NiFpga_unreserveIrqContext)
      return NiFpga_Status_ResourceNotInitialized;
   #if NiFpga_CviResourceTracking
      if (NiFpga_releaseCviResource)
         NiFpga_releaseCviResource(context);
   #endif
   return NiFpga_unreserveIrqContext(session, context);
}

static NiFpga_Status (NiFpga_CCall *NiFpga_waitOnIrqs)(
                                NiFpga_Session    session,
                                NiFpga_IrqContext context,
                                uint32_t          irqs,
                                uint32_t          timeout,
                                uint32_t*         irqsAsserted,
                                NiFpga_Bool*      timedOut) = NULL;

NiFpga_Status NiFpga_WaitOnIrqs(NiFpga_Session    session,
                                NiFpga_IrqContext context,
                                uint32_t          irqs,
                                uint32_t          timeout,
                                uint32_t*         irqsAsserted,
                                NiFpga_Bool*      timedOut)
{
   return NiFpga_waitOnIrqs
        ? NiFpga_waitOnIrqs(session,
                            context,
                            irqs,
                            timeout,
                            irqsAsserted,
                            timedOut)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acknowledgeIrqs)(
                                     NiFpga_Session session,
                                     uint32_t       irqs) = NULL;

NiFpga_Status NiFpga_AcknowledgeIrqs(NiFpga_Session session,
                                     uint32_t       irqs)
{
   return NiFpga_acknowledgeIrqs
        ? NiFpga_acknowledgeIrqs(session, irqs)
        : NiFpga_Status_ResourceNotInitialized;
}

/*
 * DMA FIFO state functions.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_configureFifo)(
                                   NiFpga_Session session,
                                   uint32_t       fifo,
                                   size_t         depth) = NULL;

NiFpga_Status NiFpga_ConfigureFifo(NiFpga_Session session,
                                   uint32_t       fifo,
                                   size_t         depth)
{
   return NiFpga_configureFifo
        ? NiFpga_configureFifo(session, fifo, depth)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_configureFifo2)(
                                   NiFpga_Session session,
                                   uint32_t       fifo,
                                   size_t         requestedDepth,
                                   size_t*        actualDepth) = NULL;

NiFpga_Status NiFpga_ConfigureFifo2(NiFpga_Session session,
                                   uint32_t       fifo,
                                   size_t         requestedDepth,
                                   size_t*        actualDepth)
{
   return NiFpga_configureFifo2
        ? NiFpga_configureFifo2(session, fifo, requestedDepth, actualDepth)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_startFifo)(
                               NiFpga_Session session,
                               uint32_t       fifo) = NULL;

NiFpga_Status NiFpga_StartFifo(NiFpga_Session session,
                               uint32_t       fifo)
{
   return NiFpga_startFifo
        ? NiFpga_startFifo(session, fifo)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_stopFifo)(
                              NiFpga_Session session,
                              uint32_t       fifo) = NULL;

NiFpga_Status NiFpga_StopFifo(NiFpga_Session session,
                              uint32_t       fifo)
{
   return NiFpga_stopFifo
        ? NiFpga_stopFifo(session, fifo)
        : NiFpga_Status_ResourceNotInitialized;
}

/*
 * Functions to read from target-to-host DMA FIFOs.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_readFifoBool)(
                                  NiFpga_Session session,
                                  uint32_t       fifo,
                                  NiFpga_Bool*   data,
                                  size_t         numberOfElements,
                                  uint32_t       timeout,
                                  size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_ReadFifoBool(NiFpga_Session session,
                                  uint32_t       fifo,
                                  NiFpga_Bool*   data,
                                  size_t         numberOfElements,
                                  uint32_t       timeout,
                                  size_t*        elementsRemaining)
{
   return NiFpga_readFifoBool
        ? NiFpga_readFifoBool(session,
                              fifo,
                              data,
                              numberOfElements,
                              timeout,
                              elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readFifoI8)(
                                NiFpga_Session session,
                                uint32_t       fifo,
                                int8_t*        data,
                                size_t         numberOfElements,
                                uint32_t       timeout,
                                size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_ReadFifoI8(NiFpga_Session session,
                                uint32_t       fifo,
                                int8_t*        data,
                                size_t         numberOfElements,
                                uint32_t       timeout,
                                size_t*        elementsRemaining)
{
   return NiFpga_readFifoI8
        ? NiFpga_readFifoI8(session,
                            fifo,
                            data,
                            numberOfElements,
                            timeout,
                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readFifoU8)(
                                NiFpga_Session session,
                                uint32_t       fifo,
                                uint8_t*       data,
                                size_t         numberOfElements,
                                uint32_t       timeout,
                                size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_ReadFifoU8(NiFpga_Session session,
                                uint32_t       fifo,
                                uint8_t*       data,
                                size_t         numberOfElements,
                                uint32_t       timeout,
                                size_t*        elementsRemaining)
{
   return NiFpga_readFifoU8
        ? NiFpga_readFifoU8(session,
                            fifo,
                            data,
                            numberOfElements,
                            timeout,
                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readFifoI16)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 int16_t*       data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_ReadFifoI16(NiFpga_Session session,
                                 uint32_t       fifo,
                                 int16_t*       data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining)
{
   return NiFpga_readFifoI16
        ? NiFpga_readFifoI16(session,
                             fifo,
                             data,
                             numberOfElements,
                             timeout,
                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readFifoU16)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 uint16_t*      data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_ReadFifoU16(NiFpga_Session session,
                                 uint32_t       fifo,
                                 uint16_t*      data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining)
{
   return NiFpga_readFifoU16
        ? NiFpga_readFifoU16(session,
                             fifo,
                             data,
                             numberOfElements,
                             timeout,
                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readFifoI32)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 int32_t*       data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_ReadFifoI32(NiFpga_Session session,
                                 uint32_t       fifo,
                                 int32_t*       data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining)
{
   return NiFpga_readFifoI32
        ? NiFpga_readFifoI32(session,
                             fifo,
                             data,
                             numberOfElements,
                             timeout,
                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readFifoU32)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 uint32_t*      data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_ReadFifoU32(NiFpga_Session session,
                                 uint32_t       fifo,
                                 uint32_t*      data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining)
{
   return NiFpga_readFifoU32
        ? NiFpga_readFifoU32(session,
                             fifo,
                             data,
                             numberOfElements,
                             timeout,
                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readFifoI64)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 int64_t*       data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_ReadFifoI64(NiFpga_Session session,
                                 uint32_t       fifo,
                                 int64_t*       data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining)
{
   return NiFpga_readFifoI64
        ? NiFpga_readFifoI64(session,
                             fifo,
                             data,
                             numberOfElements,
                             timeout,
                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_readFifoU64)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 uint64_t*      data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_ReadFifoU64(NiFpga_Session session,
                                 uint32_t       fifo,
                                 uint64_t*      data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        elementsRemaining)
{
   return NiFpga_readFifoU64
        ? NiFpga_readFifoU64(session,
                             fifo,
                             data,
                             numberOfElements,
                             timeout,
                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

/*
 * Functions to write to host-to-target DMA FIFOs.
 */
static NiFpga_Status (NiFpga_CCall *NiFpga_writeFifoBool)(
                             NiFpga_Session     session,
                             uint32_t           fifo,
                             const NiFpga_Bool* data,
                             size_t             numberOfElements,
                             uint32_t           timeout,
                             size_t*            emptyElementsRemaining) = NULL;

NiFpga_Status NiFpga_WriteFifoBool(
                             NiFpga_Session     session,
                             uint32_t           fifo,
                             const NiFpga_Bool* data,
                             size_t             numberOfElements,
                             uint32_t           timeout,
                             size_t*            emptyElementsRemaining)
{
   return NiFpga_writeFifoBool
        ? NiFpga_writeFifoBool(session,
                               fifo,
                               data,
                               numberOfElements,
                               timeout,
                               emptyElementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeFifoI8)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 const int8_t*  data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining) = NULL;

NiFpga_Status NiFpga_WriteFifoI8(NiFpga_Session session,
                                 uint32_t       fifo,
                                 const int8_t*  data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining)
{
   return NiFpga_writeFifoI8
        ? NiFpga_writeFifoI8(session,
                             fifo,
                             data,
                             numberOfElements,
                             timeout,
                             emptyElementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeFifoU8)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 const uint8_t* data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining) = NULL;

NiFpga_Status NiFpga_WriteFifoU8(NiFpga_Session session,
                                 uint32_t       fifo,
                                 const uint8_t* data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining)
{
   return NiFpga_writeFifoU8
        ? NiFpga_writeFifoU8(session,
                             fifo,
                             data,
                             numberOfElements,
                             timeout,
                             emptyElementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeFifoI16)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 const int16_t* data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining) = NULL;

NiFpga_Status NiFpga_WriteFifoI16(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 const int16_t* data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining)
{
   return NiFpga_writeFifoI16
        ? NiFpga_writeFifoI16(session,
                              fifo,
                              data,
                              numberOfElements,
                              timeout,
                              emptyElementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeFifoU16)(
                                NiFpga_Session  session,
                                uint32_t        fifo,
                                const uint16_t* data,
                                size_t          numberOfElements,
                                uint32_t        timeout,
                                size_t*         emptyElementsRemaining) = NULL;

NiFpga_Status NiFpga_WriteFifoU16(
                                NiFpga_Session  session,
                                uint32_t        fifo,
                                const uint16_t* data,
                                size_t          numberOfElements,
                                uint32_t        timeout,
                                size_t*         emptyElementsRemaining)
{
   return NiFpga_writeFifoU16
        ? NiFpga_writeFifoU16(session,
                              fifo,
                              data,
                              numberOfElements,
                              timeout,
                              emptyElementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeFifoI32)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 const int32_t* data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining) = NULL;

NiFpga_Status NiFpga_WriteFifoI32(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 const int32_t* data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining)
{
   return NiFpga_writeFifoI32
        ? NiFpga_writeFifoI32(session,
                              fifo,
                              data,
                              numberOfElements,
                              timeout,
                              emptyElementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeFifoU32)(
                                NiFpga_Session  session,
                                uint32_t        fifo,
                                const uint32_t* data,
                                size_t          numberOfElements,
                                uint32_t        timeout,
                                size_t*         emptyElementsRemaining) = NULL;

NiFpga_Status NiFpga_WriteFifoU32(
                                NiFpga_Session  session,
                                uint32_t        fifo,
                                const uint32_t* data,
                                size_t          numberOfElements,
                                uint32_t        timeout,
                                size_t*         emptyElementsRemaining)
{
   return NiFpga_writeFifoU32
        ? NiFpga_writeFifoU32(session,
                              fifo,
                              data,
                              numberOfElements,
                              timeout,
                              emptyElementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeFifoI64)(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 const int64_t* data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining) = NULL;

NiFpga_Status NiFpga_WriteFifoI64(
                                 NiFpga_Session session,
                                 uint32_t       fifo,
                                 const int64_t* data,
                                 size_t         numberOfElements,
                                 uint32_t       timeout,
                                 size_t*        emptyElementsRemaining)
{
   return NiFpga_writeFifoI64
        ? NiFpga_writeFifoI64(session,
                              fifo,
                              data,
                              numberOfElements,
                              timeout,
                              emptyElementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_writeFifoU64)(
                                NiFpga_Session  session,
                                uint32_t        fifo,
                                const uint64_t* data,
                                size_t          numberOfElements,
                                uint32_t        timeout,
                                size_t*         emptyElementsRemaining) = NULL;

NiFpga_Status NiFpga_WriteFifoU64(
                                NiFpga_Session  session,
                                uint32_t        fifo,
                                const uint64_t* data,
                                size_t          numberOfElements,
                                uint32_t        timeout,
                                size_t*         emptyElementsRemaining)
{
   return NiFpga_writeFifoU64
        ? NiFpga_writeFifoU64(session,
                              fifo,
                              data,
                              numberOfElements,
                              timeout,
                              emptyElementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoReadElementsBool)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      NiFpga_Bool**  elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoReadElementsBool(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      NiFpga_Bool**  elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoReadElementsBool
        ? NiFpga_acquireFifoReadElementsBool(session,
                                             fifo,
                                             elements,
                                             elementsRequested,
                                             timeout,
                                             elementsAcquired,
                                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoReadElementsI8)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int8_t**       elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoReadElementsI8(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int8_t**       elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoReadElementsI8
        ? NiFpga_acquireFifoReadElementsI8(session,
                                           fifo,
                                           elements,
                                           elementsRequested,
                                           timeout,
                                           elementsAcquired,
                                           elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoReadElementsU8)(
                                     NiFpga_Session  session,
                                     uint32_t        fifo,
                                     uint8_t**       elements,
                                     size_t          elementsRequested,
                                     uint32_t        timeout,
                                     size_t*         elementsAcquired,
                                     size_t*         elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoReadElementsU8(
                                     NiFpga_Session  session,
                                     uint32_t        fifo,
                                     uint8_t**       elements,
                                     size_t          elementsRequested,
                                     uint32_t        timeout,
                                     size_t*         elementsAcquired,
                                     size_t*         elementsRemaining)
{
   return NiFpga_acquireFifoReadElementsU8
        ? NiFpga_acquireFifoReadElementsU8(session,
                                           fifo,
                                           elements,
                                           elementsRequested,
                                           timeout,
                                           elementsAcquired,
                                           elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoReadElementsI16)(
                                     NiFpga_Session  session,
                                     uint32_t        fifo,
                                     int16_t**       elements,
                                     size_t          elementsRequested,
                                     uint32_t        timeout,
                                     size_t*         elementsAcquired,
                                     size_t*         elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoReadElementsI16(
                                     NiFpga_Session  session,
                                     uint32_t        fifo,
                                     int16_t**       elements,
                                     size_t          elementsRequested,
                                     uint32_t        timeout,
                                     size_t*         elementsAcquired,
                                     size_t*         elementsRemaining)
{
   return NiFpga_acquireFifoReadElementsI16
        ? NiFpga_acquireFifoReadElementsI16(session,
                                            fifo,
                                            elements,
                                            elementsRequested,
                                            timeout,
                                            elementsAcquired,
                                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoReadElementsU16)(
                                    NiFpga_Session   session,
                                    uint32_t         fifo,
                                    uint16_t**       elements,
                                    size_t           elementsRequested,
                                    uint32_t         timeout,
                                    size_t*          elementsAcquired,
                                    size_t*          elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoReadElementsU16(
                                    NiFpga_Session   session,
                                    uint32_t         fifo,
                                    uint16_t**       elements,
                                    size_t           elementsRequested,
                                    uint32_t         timeout,
                                    size_t*          elementsAcquired,
                                    size_t*          elementsRemaining)
{
   return NiFpga_acquireFifoReadElementsU16
        ? NiFpga_acquireFifoReadElementsU16(session,
                                            fifo,
                                            elements,
                                            elementsRequested,
                                            timeout,
                                            elementsAcquired,
                                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoReadElementsI32)(
                                     NiFpga_Session  session,
                                     uint32_t        fifo,
                                     int32_t**       elements,
                                     size_t          elementsRequested,
                                     uint32_t        timeout,
                                     size_t*         elementsAcquired,
                                     size_t*         elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoReadElementsI32(
                                     NiFpga_Session  session,
                                     uint32_t        fifo,
                                     int32_t**       elements,
                                     size_t          elementsRequested,
                                     uint32_t        timeout,
                                     size_t*         elementsAcquired,
                                     size_t*         elementsRemaining)
{
   return NiFpga_acquireFifoReadElementsI32
        ? NiFpga_acquireFifoReadElementsI32(session,
                                            fifo,
                                            elements,
                                            elementsRequested,
                                            timeout,
                                            elementsAcquired,
                                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoReadElementsU32)(
                                    NiFpga_Session   session,
                                    uint32_t         fifo,
                                    uint32_t**       elements,
                                    size_t           elementsRequested,
                                    uint32_t         timeout,
                                    size_t*          elementsAcquired,
                                    size_t*          elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoReadElementsU32(
                                    NiFpga_Session   session,
                                    uint32_t         fifo,
                                    uint32_t**       elements,
                                    size_t           elementsRequested,
                                    uint32_t         timeout,
                                    size_t*          elementsAcquired,
                                    size_t*          elementsRemaining)
{
   return NiFpga_acquireFifoReadElementsU32
        ? NiFpga_acquireFifoReadElementsU32(session,
                                            fifo,
                                            elements,
                                            elementsRequested,
                                            timeout,
                                            elementsAcquired,
                                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoReadElementsI64)(
                                     NiFpga_Session  session,
                                     uint32_t        fifo,
                                     int64_t**       elements,
                                     size_t          elementsRequested,
                                     uint32_t        timeout,
                                     size_t*         elementsAcquired,
                                     size_t*         elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoReadElementsI64(
                                     NiFpga_Session  session,
                                     uint32_t        fifo,
                                     int64_t**       elements,
                                     size_t          elementsRequested,
                                     uint32_t        timeout,
                                     size_t*         elementsAcquired,
                                     size_t*         elementsRemaining)
{
   return NiFpga_acquireFifoReadElementsI64
        ? NiFpga_acquireFifoReadElementsI64(session,
                                            fifo,
                                            elements,
                                            elementsRequested,
                                            timeout,
                                            elementsAcquired,
                                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoReadElementsU64)(
                                    NiFpga_Session   session,
                                    uint32_t         fifo,
                                    uint64_t**       elements,
                                    size_t           elementsRequested,
                                    uint32_t         timeout,
                                    size_t*          elementsAcquired,
                                    size_t*          elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoReadElementsU64(
                                    NiFpga_Session   session,
                                    uint32_t         fifo,
                                    uint64_t**       elements,
                                    size_t           elementsRequested,
                                    uint32_t         timeout,
                                    size_t*          elementsAcquired,
                                    size_t*          elementsRemaining)
{
   return NiFpga_acquireFifoReadElementsU64
        ? NiFpga_acquireFifoReadElementsU64(session,
                                            fifo,
                                            elements,
                                            elementsRequested,
                                            timeout,
                                            elementsAcquired,
                                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoWriteElementsBool)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      NiFpga_Bool**  elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoWriteElementsBool(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      NiFpga_Bool**  elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoWriteElementsBool
        ? NiFpga_acquireFifoWriteElementsBool(session,
                                              fifo,
                                              elements,
                                              elementsRequested,
                                              timeout,
                                              elementsAcquired,
                                              elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoWriteElementsI8)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int8_t**       elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoWriteElementsI8(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int8_t**       elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoWriteElementsI8
        ? NiFpga_acquireFifoWriteElementsI8(session,
                                            fifo,
                                            elements,
                                            elementsRequested,
                                            timeout,
                                            elementsAcquired,
                                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoWriteElementsU8)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      uint8_t**      elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoWriteElementsU8(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      uint8_t**      elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoWriteElementsU8
        ? NiFpga_acquireFifoWriteElementsU8(session,
                                            fifo,
                                            elements,
                                            elementsRequested,
                                            timeout,
                                            elementsAcquired,
                                            elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoWriteElementsI16)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int16_t**      elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoWriteElementsI16(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int16_t**      elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoWriteElementsI16
        ? NiFpga_acquireFifoWriteElementsI16(session,
                                             fifo,
                                             elements,
                                             elementsRequested,
                                             timeout,
                                             elementsAcquired,
                                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoWriteElementsU16)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      uint16_t**     elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoWriteElementsU16(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      uint16_t**     elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoWriteElementsU16
        ? NiFpga_acquireFifoWriteElementsU16(session,
                                             fifo,
                                             elements,
                                             elementsRequested,
                                             timeout,
                                             elementsAcquired,
                                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoWriteElementsI32)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int32_t**      elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoWriteElementsI32(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int32_t**      elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoWriteElementsI32
        ? NiFpga_acquireFifoWriteElementsI32(session,
                                             fifo,
                                             elements,
                                             elementsRequested,
                                             timeout,
                                             elementsAcquired,
                                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoWriteElementsU32)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      uint32_t**     elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoWriteElementsU32(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      uint32_t**     elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoWriteElementsU32
        ? NiFpga_acquireFifoWriteElementsU32(session,
                                             fifo,
                                             elements,
                                             elementsRequested,
                                             timeout,
                                             elementsAcquired,
                                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoWriteElementsI64)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int64_t**      elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoWriteElementsI64(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      int64_t**      elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoWriteElementsI64
        ? NiFpga_acquireFifoWriteElementsI64(session,
                                             fifo,
                                             elements,
                                             elementsRequested,
                                             timeout,
                                             elementsAcquired,
                                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_acquireFifoWriteElementsU64)(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      uint64_t**     elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining) = NULL;

NiFpga_Status NiFpga_AcquireFifoWriteElementsU64(
                                      NiFpga_Session session,
                                      uint32_t       fifo,
                                      uint64_t**     elements,
                                      size_t         elementsRequested,
                                      uint32_t       timeout,
                                      size_t*        elementsAcquired,
                                      size_t*        elementsRemaining)
{
   return NiFpga_acquireFifoWriteElementsU64
        ? NiFpga_acquireFifoWriteElementsU64(session,
                                             fifo,
                                             elements,
                                             elementsRequested,
                                             timeout,
                                             elementsAcquired,
                                             elementsRemaining)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_releaseFifoElements)(
                                         NiFpga_Session session,
                                         uint32_t       fifo,
                                         size_t         elements) = NULL;

NiFpga_Status NiFpga_ReleaseFifoElements(NiFpga_Session session,
                                         uint32_t       fifo,
                                         size_t         elements)
{
   return NiFpga_releaseFifoElements
        ? NiFpga_releaseFifoElements(session, fifo, elements)
        : NiFpga_Status_ResourceNotInitialized;
}

static NiFpga_Status (NiFpga_CCall *NiFpga_getPeerToPeerFifoEndpoint)(
                                         NiFpga_Session session,
                                         uint32_t       fifo,
                                         uint32_t*      endpoint) = NULL;

NiFpga_Status NiFpga_GetPeerToPeerFifoEndpoint(NiFpga_Session session,
                                         uint32_t       fifo,
                                         uint32_t*      endpoint)
{
   return NiFpga_getPeerToPeerFifoEndpoint
        ? NiFpga_getPeerToPeerFifoEndpoint(session, fifo, endpoint)
        : NiFpga_Status_ResourceNotInitialized;
}

/**
 * A NULL-terminated array of all entry point functions.
 */
static const struct
{
   const char* const name;
   void** const address;
} NiFpga_functions[] =
{
   {"NiFpgaDll_Open",                (void**)(void*)&NiFpga_open},
   {"NiFpgaDll_Close",               (void**)(void*)&NiFpga_close},
   {"NiFpgaDll_Run",                 (void**)(void*)&NiFpga_run},
   {"NiFpgaDll_Abort",               (void**)(void*)&NiFpga_abort},
   {"NiFpgaDll_Reset",               (void**)(void*)&NiFpga_reset},
   {"NiFpgaDll_Download",            (void**)(void*)&NiFpga_download},
   {"NiFpgaDll_ReadBool",            (void**)(void*)&NiFpga_readBool},
   {"NiFpgaDll_ReadI8",              (void**)(void*)&NiFpga_readI8},
   {"NiFpgaDll_ReadU8",              (void**)(void*)&NiFpga_readU8},
   {"NiFpgaDll_ReadI16",             (void**)(void*)&NiFpga_readI16},
   {"NiFpgaDll_ReadU16",             (void**)(void*)&NiFpga_readU16},
   {"NiFpgaDll_ReadI32",             (void**)(void*)&NiFpga_readI32},
   {"NiFpgaDll_ReadU32",             (void**)(void*)&NiFpga_readU32},
   {"NiFpgaDll_ReadI64",             (void**)(void*)&NiFpga_readI64},
   {"NiFpgaDll_ReadU64",             (void**)(void*)&NiFpga_readU64},
   {"NiFpgaDll_WriteBool",           (void**)(void*)&NiFpga_writeBool},
   {"NiFpgaDll_WriteI8",             (void**)(void*)&NiFpga_writeI8},
   {"NiFpgaDll_WriteU8",             (void**)(void*)&NiFpga_writeU8},
   {"NiFpgaDll_WriteI16",            (void**)(void*)&NiFpga_writeI16},
   {"NiFpgaDll_WriteU16",            (void**)(void*)&NiFpga_writeU16},
   {"NiFpgaDll_WriteI32",            (void**)(void*)&NiFpga_writeI32},
   {"NiFpgaDll_WriteU32",            (void**)(void*)&NiFpga_writeU32},
   {"NiFpgaDll_WriteI64",            (void**)(void*)&NiFpga_writeI64},
   {"NiFpgaDll_WriteU64",            (void**)(void*)&NiFpga_writeU64},
   {"NiFpgaDll_ReadArrayBool",       (void**)(void*)&NiFpga_readArrayBool},
   {"NiFpgaDll_ReadArrayI8",         (void**)(void*)&NiFpga_readArrayI8},
   {"NiFpgaDll_ReadArrayU8",         (void**)(void*)&NiFpga_readArrayU8},
   {"NiFpgaDll_ReadArrayI16",        (void**)(void*)&NiFpga_readArrayI16},
   {"NiFpgaDll_ReadArrayU16",        (void**)(void*)&NiFpga_readArrayU16},
   {"NiFpgaDll_ReadArrayI32",        (void**)(void*)&NiFpga_readArrayI32},
   {"NiFpgaDll_ReadArrayU32",        (void**)(void*)&NiFpga_readArrayU32},
   {"NiFpgaDll_ReadArrayI64",        (void**)(void*)&NiFpga_readArrayI64},
   {"NiFpgaDll_ReadArrayU64",        (void**)(void*)&NiFpga_readArrayU64},
   {"NiFpgaDll_WriteArrayBool",      (void**)(void*)&NiFpga_writeArrayBool},
   {"NiFpgaDll_WriteArrayI8",        (void**)(void*)&NiFpga_writeArrayI8},
   {"NiFpgaDll_WriteArrayU8",        (void**)(void*)&NiFpga_writeArrayU8},
   {"NiFpgaDll_WriteArrayI16",       (void**)(void*)&NiFpga_writeArrayI16},
   {"NiFpgaDll_WriteArrayU16",       (void**)(void*)&NiFpga_writeArrayU16},
   {"NiFpgaDll_WriteArrayI32",       (void**)(void*)&NiFpga_writeArrayI32},
   {"NiFpgaDll_WriteArrayU32",       (void**)(void*)&NiFpga_writeArrayU32},
   {"NiFpgaDll_WriteArrayI64",       (void**)(void*)&NiFpga_writeArrayI64},
   {"NiFpgaDll_WriteArrayU64",       (void**)(void*)&NiFpga_writeArrayU64},
   {"NiFpgaDll_ReserveIrqContext",   (void**)(void*)&NiFpga_reserveIrqContext},
   {"NiFpgaDll_UnreserveIrqContext", (void**)(void*)&NiFpga_unreserveIrqContext},
   {"NiFpgaDll_WaitOnIrqs",          (void**)(void*)&NiFpga_waitOnIrqs},
   {"NiFpgaDll_AcknowledgeIrqs",     (void**)(void*)&NiFpga_acknowledgeIrqs},
   {"NiFpgaDll_ConfigureFifo",       (void**)(void*)&NiFpga_configureFifo},
   {"NiFpgaDll_ConfigureFifo2",      (void**)(void*)&NiFpga_configureFifo2},
   {"NiFpgaDll_StartFifo",           (void**)(void*)&NiFpga_startFifo},
   {"NiFpgaDll_StopFifo",            (void**)(void*)&NiFpga_stopFifo},
   {"NiFpgaDll_ReadFifoBool",        (void**)(void*)&NiFpga_readFifoBool},
   {"NiFpgaDll_ReadFifoI8",          (void**)(void*)&NiFpga_readFifoI8},
   {"NiFpgaDll_ReadFifoU8",          (void**)(void*)&NiFpga_readFifoU8},
   {"NiFpgaDll_ReadFifoI16",         (void**)(void*)&NiFpga_readFifoI16},
   {"NiFpgaDll_ReadFifoU16",         (void**)(void*)&NiFpga_readFifoU16},
   {"NiFpgaDll_ReadFifoI32",         (void**)(void*)&NiFpga_readFifoI32},
   {"NiFpgaDll_ReadFifoU32",         (void**)(void*)&NiFpga_readFifoU32},
   {"NiFpgaDll_ReadFifoI64",         (void**)(void*)&NiFpga_readFifoI64},
   {"NiFpgaDll_ReadFifoU64",         (void**)(void*)&NiFpga_readFifoU64},
   {"NiFpgaDll_WriteFifoBool",       (void**)(void*)&NiFpga_writeFifoBool},
   {"NiFpgaDll_WriteFifoI8",         (void**)(void*)&NiFpga_writeFifoI8},
   {"NiFpgaDll_WriteFifoU8",         (void**)(void*)&NiFpga_writeFifoU8},
   {"NiFpgaDll_WriteFifoI16",        (void**)(void*)&NiFpga_writeFifoI16},
   {"NiFpgaDll_WriteFifoU16",        (void**)(void*)&NiFpga_writeFifoU16},
   {"NiFpgaDll_WriteFifoI32",        (void**)(void*)&NiFpga_writeFifoI32},
   {"NiFpgaDll_WriteFifoU32",        (void**)(void*)&NiFpga_writeFifoU32},
   {"NiFpgaDll_WriteFifoI64",        (void**)(void*)&NiFpga_writeFifoI64},
   {"NiFpgaDll_WriteFifoU64",        (void**)(void*)&NiFpga_writeFifoU64},
   {"NiFpgaDll_AcquireFifoReadElementsBool",  (void**)(void*)&NiFpga_acquireFifoReadElementsBool},
   {"NiFpgaDll_AcquireFifoReadElementsI8",    (void**)(void*)&NiFpga_acquireFifoReadElementsI8},
   {"NiFpgaDll_AcquireFifoReadElementsU8",    (void**)(void*)&NiFpga_acquireFifoReadElementsU8},
   {"NiFpgaDll_AcquireFifoReadElementsI16",   (void**)(void*)&NiFpga_acquireFifoReadElementsI16},
   {"NiFpgaDll_AcquireFifoReadElementsU16",   (void**)(void*)&NiFpga_acquireFifoReadElementsU16},
   {"NiFpgaDll_AcquireFifoReadElementsI32",   (void**)(void*)&NiFpga_acquireFifoReadElementsI32},
   {"NiFpgaDll_AcquireFifoReadElementsU32",   (void**)(void*)&NiFpga_acquireFifoReadElementsU32},
   {"NiFpgaDll_AcquireFifoReadElementsI64",   (void**)(void*)&NiFpga_acquireFifoReadElementsI64},
   {"NiFpgaDll_AcquireFifoReadElementsU64",   (void**)(void*)&NiFpga_acquireFifoReadElementsU64},
   {"NiFpgaDll_AcquireFifoWriteElementsBool", (void**)(void*)&NiFpga_acquireFifoWriteElementsBool},
   {"NiFpgaDll_AcquireFifoWriteElementsI8",   (void**)(void*)&NiFpga_acquireFifoWriteElementsI8},
   {"NiFpgaDll_AcquireFifoWriteElementsU8",   (void**)(void*)&NiFpga_acquireFifoWriteElementsU8},
   {"NiFpgaDll_AcquireFifoWriteElementsI16",  (void**)(void*)&NiFpga_acquireFifoWriteElementsI16},
   {"NiFpgaDll_AcquireFifoWriteElementsU16",  (void**)(void*)&NiFpga_acquireFifoWriteElementsU16},
   {"NiFpgaDll_AcquireFifoWriteElementsI32",  (void**)(void*)&NiFpga_acquireFifoWriteElementsI32},
   {"NiFpgaDll_AcquireFifoWriteElementsU32",  (void**)(void*)&NiFpga_acquireFifoWriteElementsU32},
   {"NiFpgaDll_AcquireFifoWriteElementsI64",  (void**)(void*)&NiFpga_acquireFifoWriteElementsI64},
   {"NiFpgaDll_AcquireFifoWriteElementsU64",  (void**)(void*)&NiFpga_acquireFifoWriteElementsU64},
   {"NiFpgaDll_ReleaseFifoElements",          (void**)(void*)&NiFpga_releaseFifoElements},
   {"NiFpgaDll_GetPeerToPeerFifoEndpoint",    (void**)(void*)&NiFpga_getPeerToPeerFifoEndpoint},
   {NULL, NULL}
};

NiFpga_Status NiFpga_Initialize(void)
{
   /* if the library isn't already loaded */
   if (!NiFpga_library)
   {
      int i;
      /* load the library */
      #if NiFpga_Windows
         NiFpga_library = LoadLibraryA("NiFpga.dll");
      #elif NiFpga_VxWorks
         NiFpga_library = VxLoadLibraryFromPath("NiFpga.out", 0);
      #elif NiFpga_Linux
         const char* const library = "libNiFpga.so";
         NiFpga_library = dlopen(library, RTLD_LAZY);
         if (!NiFpga_library)
            fprintf(stderr, "Error opening %s: %s\n", library, dlerror());
      #else
         #error
      #endif
      if (!NiFpga_library)
         return NiFpga_Status_ResourceNotFound;
      /* get each exported function */
      for (i = 0; NiFpga_functions[i].name; i++)
      {
         const char* const name = NiFpga_functions[i].name;
         void** const address = NiFpga_functions[i].address;
         #if NiFpga_Windows
            *address = GetProcAddress(NiFpga_library, name);
            if (!*address)
               return NiFpga_Status_VersionMismatch;
         #elif NiFpga_VxWorks
            SYM_TYPE type;
            if (symFindByName(sysSymTbl,
                              (char*)name,
                              (char**)address,
                              &type) != OK)
               return NiFpga_Status_VersionMismatch;
         #elif NiFpga_Linux
            *address = dlsym(NiFpga_library, name);
            if (!*address)
               return NiFpga_Status_VersionMismatch;
         #else
            #error
         #endif
      }
      /* enable CVI Resource Tracking, if available */
      #if NiFpga_CviResourceTracking
      {
         HMODULE engine = GetModuleHandle("cvirte.dll");
         if (!engine)
            engine = GetModuleHandle("cvi_lvrt.dll");
         if (!engine)
            engine = GetModuleHandle("instrsup.dll");
         if (engine)
         {
            NiFpga_acquireCviResource =
               (NiFpga_AcquireCviResource)
                  GetProcAddress(engine, "__CVI_Resource_Acquire");
            NiFpga_releaseCviResource =
               (NiFpga_ReleaseCviResource)
                  GetProcAddress(engine, "__CVI_Resource_Release");
            if (!NiFpga_acquireCviResource
            ||  !NiFpga_releaseCviResource)
            {
               NiFpga_acquireCviResource = NULL;
               NiFpga_releaseCviResource = NULL;
            }
         }
      }
      #endif
   }
   return NiFpga_Status_Success;
}

NiFpga_Status NiFpga_Finalize(void)
{
   /* if the library is currently loaded */
   if (NiFpga_library)
   {
      int i;
      NiFpga_Status status = NiFpga_Status_Success;
      /* unload the library */
      #if NiFpga_Windows
         if (!FreeLibrary(NiFpga_library))
            status = NiFpga_Status_ResourceNotInitialized;
      #elif NiFpga_VxWorks
         if (VxFreeLibrary(NiFpga_library, 0) != OK)
            status = NiFpga_Status_ResourceNotInitialized;
      #elif NiFpga_Linux
         if (dlclose(NiFpga_library))
            status = NiFpga_Status_ResourceNotInitialized;
      #else
         #error
      #endif
      /* null out the library and each exported function */
      NiFpga_library = NULL;
      for (i = 0; NiFpga_functions[i].name; i++)
         *NiFpga_functions[i].address = NULL;
      /* null out the CVI Resource Tracking functions */
      #if NiFpga_CviResourceTracking
         NiFpga_acquireCviResource = NULL;
         NiFpga_releaseCviResource = NULL;
      #endif
      return status;
   }
   else
      return NiFpga_Status_ResourceNotInitialized;
}
