project('mkinitrd', 'c')

srcs = ['config.sh',
        'functions.sh',
        'init.sh',
        'optparse.sh'
]

install_subdir('src/hooks/', install_dir: '/etc/initrd/')
install_subdir('src/scripts/', install_dir: '/etc/initrd/')
foreach src : srcs
    install_data('src'/src, install_dir: '/etc/initrd/')
endforeach
install_data(
    'src/mkinitrd.sh', 
    install_dir: get_option('bindir'), 
    install_mode: 'rwxr-xr-x',
    rename: 'mkinitrd'
)
