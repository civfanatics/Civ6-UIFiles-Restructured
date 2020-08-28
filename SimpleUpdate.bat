set MY_CIV6="C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization VI"
rmdir /q /s Base\Assets\UI
rmdir /q /s DLC\Expansion1\UI
rmdir /q /s DLC\Expansion2\UI
mkdir Base\Assets\UI
mkdir DLC\Expansion1\UI
mkdir DLC\Expansion2\UI
xcopy %MY_CIV6%\Base\Assets\UI Base\Assets\UI /e
xcopy %MY_CIV6%\DLC\Expansion1\UI DLC\Expansion1\UI /e
xcopy %MY_CIV6%\DLC\Expansion2\UI DLC\Expansion2\UI /e
copy %MY_CIV6%\DLC\Expansion1\Expansion1.dep DLC\Expansion1 /y
copy %MY_CIV6%\DLC\Expansion2\Expansion2.dep DLC\Expansion2 /y
copy %MY_CIV6%\DLC\Expansion1\Expansion1.modinfo DLC\Expansion1 /y
copy %MY_CIV6%\DLC\Expansion2\Expansion2.modinfo DLC\Expansion2 /y
