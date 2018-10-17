Pod::Spec.new do |s|

  s.name         = "lzma"
  s.version      = "5.2.4"
  s.summary      = "Library for XZ and LZMA compressed files"
  s.homepage     = "https://tukaani.org/xz/"
  s.license      = { :type => "multiple", :file => "COPYING" }
  s.author       = { "Lasse Collin" => "lasse.collin@tukaani.org" }
  s.source       = { :git => "https://git.tukaani.org/xz.git", :tag => "v5.2.4" }
  s.source_files  = "src/common/*.{c,h,ch}", "src/liblzma/check/*.{c,h,ch}", "src/liblzma/simple/*.{c,h,ch}", "src/liblzma/delta/*.{c,h,ch}", "src/liblzma/lzma/*.{c,h,ch}", "src/liblzma/rangecoder/*.{c,h,ch}", "src/liblzma/lz/*.{c,h,ch}", "src/liblzma/common/*.{c,h,ch}", "src/liblzma/api/*.h"
  s.exclude_files  = "src/liblzma/check/crc64_small.*", "src/liblzma/check/crc32_small.*"
  s.preserve_paths = "src/liblzma/api/lzma/*.h"
  s.prefix_header_contents = '#include <string.h>'
  s.public_header_files = "src/liblzma/api/*.h"
  s.compiler_flags = [
    "-DHAVE_STDINT_H=1",
    "-DHAVE_STDBOOL_H=1",
    "-DHAVE_MEMSET=1",
    "-DHAVE_STRING_H=1",
    "-DMYTHREAD_POSIX=1",
    "-DHAVE_DECODER_LZMA1=1",
    "-DHAVE_ENCODER_LZMA1=1",
    "-DHAVE_DECODER_LZMA2=1",
    "-DHAVE_ENCODER_LZMA2=1",
    "-DHAVE_CHECK_CRC32=1",
    "-DHAVE_CHECK_CRC64=1",
    "-DHAVE_CHECK_SHA256=1",
    "-DHAVE_MF_HC3=1",
    "-DHAVE_MF_HC4=1",
    "-DHAVE_MF_BT2=1",
    "-DHAVE_MF_BT3=1",
    "-DHAVE_MF_BT4=1",
  ]
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/lzma/src/liblzma/api"',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
end
