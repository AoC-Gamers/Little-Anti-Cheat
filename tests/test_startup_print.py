"""Execute the production startup callback with modeled console/config boundaries."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]


def function(source,name):
    m=re.search(r'public void '+name+r'\([^)]*\)\s*\{',source)
    end,depth=m.end(),1
    while depth:
        depth+=(source[end]=='{')-(source[end]=='}');end+=1
    return source[m.start():end].replace('public ','')


class StartupPrintTests(unittest.TestCase):
    def test_default_silence_enabled_print_and_once_per_load(self):
        entry=(ROOT/'addons/sourcemod/scripting/lilac.sp').read_text()
        config=(ROOT/'addons/sourcemod/scripting/lilac/lilac_config.sp').read_text()
        self.assertNotIn('PrintToServer',function(entry,'OnAllPluginsLoaded'))
        self.assertRegex(config,r'new Convar\("lilac_startup_print", "0",[^;]+true, 0\.0, true, 1\.0\)')
        callback=function(config,'OnConfigsExecuted')
        code=r'''
#include <cassert>
#include <cstdlib>
struct Cvar {bool BoolValue=false;}g_cvStartupPrint;
constexpr const char* PLUGIN_VERSION="test";
int banners=0,reports=0,presets=0,database=0;
void PrintToServer(const char*,const char*){banners++;}
void lilac_ban_status(int){reports++;}
void lilac_bhop_set_preset(){presets++;}
void Database_OnConfigExecuted(){database++;}
'''+callback+r'''
int main(int argc,char**){g_cvStartupPrint.BoolValue=argc>1;OnConfigsExecuted();
 assert(banners==(argc>1?1:0)&&reports==banners&&presets==1&&database==1);
 g_cvStartupPrint.BoolValue=!g_cvStartupPrint.BoolValue;OnConfigsExecuted();
 assert(banners==(argc>1?1:0)&&reports==banners&&presets==2&&database==2);
 lilac_ban_status(0);assert(reports==banners+1);}
'''
        with tempfile.TemporaryDirectory(prefix='lilac-startup-') as directory:
            cpp,binary=Path(directory)/'test.cpp',Path(directory)/'test';cpp.write_text(code)
            subprocess.run(['g++','-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',
                            '-fno-pie','-no-pie',str(cpp),'-o',str(binary)],check=True)
            subprocess.run([str(binary)],check=True)
            subprocess.run([str(binary),'configured-print'],check=True)
