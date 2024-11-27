project('mkinitrd', 'c')

srcs = ['config.sh',
        'functions.sh',
        'optparse.sh'
]

executable('init', 'src/init.c', install_dir:'/etc/initrd')

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
