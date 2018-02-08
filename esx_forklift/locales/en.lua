-- HOW TO LOCALIZE THIS SCRIPT:
--   -replace all strings used in client - script communication with _U('STRING_NAME')
--      where string name is the name of the string declared here.
--
--		For example: ESX.Shownotification(_U('not_enough'))
--					and the string below will be displayed to the player

Locales['en'] = { --Locales['x'], replace is x with your language. For example 'fr' and set Config.Locale = ['fr'] in config.lua
		  --You will also have to add your localization file to the __resource.lua
    ['not_enough'] = 'You do not have enough money, you poor bastard.',
	['another_example'] = 'more strings'

}
