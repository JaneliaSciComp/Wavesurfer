call "c:\Program Files (x86)\Microsoft Visual Studio 9.0\Common7\Tools\vsvars32.bat"

pushd +ws\mex

msbuild /p:Configuration=Release

popd
