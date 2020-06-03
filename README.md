# Civ6-UIFiles-Restructured
 
Unmodded UI files for Civ6. Based on repo from https://github.com/Azurency/Civ6-UIFiles but reorganized to match the game's file structure.

## Simple Update Process
1. Clone repo to a local location
2. Delete the Base/Assets/UI folder
3. Copy folder from <CIV6_Install_Location>/Base/Assets/UI into Base/Assets
4. Delete DLC/Expansion1/UI folder
5. Copy folder from <CIV6_Install_Location>/DLC/Expansion1/UI into DLC/Expansion1
6. Copy files Expansion1.dep and Expansion1.modinfo from <CIV6_Install_Location>/DLC/Expansion1 into DLC/Expansion1
7. Delete DLC/Expansion2/UI folder
8. Copy folder from <CIV6_Install_Location>/DLC/Expansion2/UI into DLC/Expansion2
9. Copy files Expansion2.dep and Expansion2.modinfo from <CIV6_Install_Location>/DLC/Expansion2 into DLC/Expansion2
10. Use GitHub Desktop application to commit all files (modified, added, removed) or use `git add -A` followed by commit

## Update process to link line history for new files in ExpansionX folder
1. Check to see if files are added to ExpansionX folder, if no new files then use simple process
2. Check if file exists in earlier expansions or base game, if file did not exist then use simple process
3. Create a branch for preparation work `git checkout -b ExpansionXPrep`
4. Move files from old location (earlier expansion or base game) into new location
5. Stage all moved files `git add -A`
6. Commit files `git commit -m "Prep for ExpansionX update"`
7. Restore moved files to old location `git checkout HEAD~ Base`, `git checkout HEAD~ DLC\Expansion1`, ...
8. Commit files `git commit -m "Restore common files"`
9. Switch back to master `git checkout -`
10. Merge the branch into master `git merge --no-ff ExpansionXPrep`
11. Follow simple process to do the remaining updates

Based on instructions from https://devblogs.microsoft.com/oldnewthing/20190919-00/?p=102904
