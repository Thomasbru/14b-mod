# 14b-mod
norns mod for mapping 14-bit midi to params

usage: takes up to 14 bits of midi (2 channels) and maps them to general and script specific parameters

# setup:
	in script
	change function/table generating MSB - LSB list
	currently hardcoded from bleached alternate firmware,
	hosted at https://github.com/Thomasbru/bleached

	bit reduction can also be changed, to reflect the true resolution from device
	(Teensy LC can for instance only poll 12 bit values from encoder)

# control:
	from mod menu,
	E3 changes parameter
	E2 changes midi input
	currently all addresses are mapped from same device

	K2 exits mod menu
	K3 makes parameter mappable
		midi input maps parameter, K2 again exits
	K1 + K3 saves mappings
	K1 + K2 loads mappings

midi device is saved on exit mod menu, mappings are saved on a per script basis in the folder /data/14b-mod/




