project('mkinitrd', 'c')

srcs = ['config.sh',
        'functions.sh',
        'optparse.sh'
]

add_project_arguments('-Wextra', language: 'c')
add_project_arguments('-Wall', language: 'c')
add_project_arguments('-Werror', language: 'c')
add_project_arguments('-fvisibility=hidden', language: 'c')
add_project_arguments('-fno-plt', language: 'c')

executable('init', 'src/init.c', install_dir:'/etc/initrd', install: true)

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

install_data(
    'src/mkunify.sh',
    install_dir: get_option('bindir'),
    install_mode: 'rwxr-xr-x',
    rename: 'mkunify'
)
