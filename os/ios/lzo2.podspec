Pod::Spec.new do |s|

  s.name         = "lzo2"
  s.version      = "2.10"
  s.summary      = "LZO -- a real-time data compression library"
  s.homepage     = "http://www.oberhumer.com/opensource/lzo/"
  s.license      = { :type => "GPLv2", :file => "COPYING" }
  s.author             = { "Markus F.X.J. Oberhumer" => "info@oberhumer.com" }
  s.source       = { :git => "https://github.com/damageboy/lzo2.git", :commit => "8809e38dddd719b518dbf86fad8fe0cdd9f6c1c4" }
  s.source_files  = "src/*.{c,h,ch}", "include/lzo/*.h"
  s.public_header_files = "include/lzo/*.h"
  s.compiler_flags = [
    "-DLZO_CFG_NO_CONFIG_HEADER=1",
    "-DLZO_ABI_LITTLE_ENDIAN=1",
    "-DHAVE_MEMCMP=1",
    "-DHAVE_MEMCPY=1",
    "-DHAVE_MEMMOVE=1",
    "-DHAVE_MEMSET=1"
  ]
  s.xcconfig = { 
    'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/lzo2/include"',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
end
