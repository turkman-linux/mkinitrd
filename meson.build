project('mkinitrd', 'c')

install_subdir('src', install_dir: '/etc/initrd')
install_data(
    'src/mkinitrd.sh', 
    install_dir: get_option('bindir'), 
    install_mode: 'rwxr-xr-x'
)