MCCacheRepository instVarNamed: 'default' put: nil.
"GemTools"
Installer ss
  project: 'MetacelloRepository';
  install: 'ConfigurationOfGemTools'.
ConfigurationOfGemTools loadLatestVersion.
OGLauncher open.
"Clear Monticello Caches"
MCCacheRepository instVarNamed: 'default' put: nil.
MCFileBasedRepository flushAllCaches.
MCMethodDefinition shutDown.
MCDefinition clearInstances.
"Cleanup Smalltalk"
Smalltalk flushClassNameCache.
Smalltalk organization removeEmptyCategories.
Smalltalk allClassesAndTraitsDo: [ :each |
	each organization removeEmptyCategories; sortCategories.
	each class organization removeEmptyCategories; sortCategories ].
"Cleanup System Memory"
Smalltalk garbageCollect.
Symbol compactSymbolTable.

