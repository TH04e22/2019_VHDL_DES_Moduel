vcom DES/DES_def.vhd
vcom DES/DES_module.vhd
vcom DES/DesTb.vhd
vsim work.DesTb
view wave
view object
radix Hexadecimal
add wave DesTb/Clock
add wave DesTb/ED_Sel
add wave DesTb/En
add wave DesTb/Input
add wave DesTb/Key
add wave DesTb/Output
run 400 ns
wave zoom full