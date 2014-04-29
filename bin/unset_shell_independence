# All shells.
unalias ifcsh_ endif endifcsh_
unset ss
# csh only
test $?shell = 1 && \
    unalias vecho_ set_ unsetenv_ tnotnull nullout return
# sh only
test $?shell != 1 && \
    unset vecho_ set_ setenv source unsetenv_ tnotnull nullout
# bash only
test $?shell != 1 && test "${BASH}" && test "${old_expand_aliases}" && \
    eval ${old_expand_aliases}
echo "" > /dev/null
