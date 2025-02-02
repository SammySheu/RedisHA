#!/bin/bash
# Writed by yijian on 2018/9/2
# Query the memory of all nodes in a cluster
#
# Output example:
# $ ./query_redis_cluster.sh 192.168.0.31.21:6379
# [192.168.0.31.21:6379]  Used: 788.57M   Max: 15.00G    System: 125.56G
# [192.168.0.31.22:6380]  Used: 756.98M   Max: 15.00G    System: 125.56G
# [192.168.0.31.23:6380]  Used: 743.93M   Max: 15.00G    System: 125.56G
# [192.168.0.31.24:6380]  Used: 21.73M    Max: 15.00G    System: 125.56G
# [192.168.0.31.25:6380]  Used: 819.11M   Max: 15.00G    System: 125.56G
# [192.168.0.31.24:6379]  Used: 771.70M   Max: 15.00G    System: 125.56G
# [192.168.0.31.26:6379]  Used: 920.77M   Max: 15.00G    System: 125.56G
# [192.168.0.31.27:6380]  Used: 889.09M   Max: 15.00G    System: 125.27G
# [192.168.0.31.28:6379]  Used: 741.24M   Max: 15.00G    System: 125.56G
# [192.168.0.31.29:6380]  Used: 699.55M   Max: 15.00G    System: 125.56G
# [192.168.0.31.27:6379]  Used: 752.89M   Max: 15.00G    System: 125.27G
# [192.168.0.31.21:6380]  Used: 716.05M   Max: 15.00G    System: 125.56G
# [192.168.0.31.23:6379]  Used: 784.82M   Max: 15.00G    System: 125.56G
# [192.168.0.31.26:6380]  Used: 726.40M   Max: 15.00G    System: 125.56G
# [192.168.0.31.25:6379]  Used: 726.09M   Max: 15.00G    System: 125.56G
# [192.168.0.31.29:6379]  Used: 844.59M   Max: 15.00G    System: 125.56G
# [192.168.0.31.28:6380]  Used: 14.00M    Max: 15.00G    System: 125.56G
# [192.168.0.31.22:6379]  Used: 770.13M   Max: 15.00G    System: 125.56G

REDIS_CLI=${REDIS_CLI:-redis-cli}
REDIS_IP=${REDIS_IP:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}

function usage()
{
    echo "Usage: `basename $0` redis_node [redis-password]"
    echo "Example1: `basename $0` 127.0.0.1:6379"
    echo "Example2: `basename $0` 127.0.0.1:6379 redis-password"
}

# with two parameters:
# 1) single redis node
# 2) redis password
if test $# -eq 0 -o $# -gt 2; then
    usage
    exit 1
fi

# 如果有两个参数，则第2个参数为密码
redis_password=
if test $# -eq 2; then
    redis_password="$2"
fi

eval $(echo "$1" | awk -F[\:] '{ printf("REDIS_IP=%s\nREDIS_PORT=%s\n",$1,$2) }')
if test -z "$REDIS_IP" -o -z "$REDIS_PORT"; then
    echo "Parameter error"
    usage
    exit 1
fi

# 确保redis-cli可用
which "$REDIS_CLI" > /dev/null 2>&1
if test $? -ne 0; then
    echo "\`redis-cli\` not exists or not executable"
    exit 1
fi

if test -z "$redis_password"; then
    redis_nodes=`redis-cli -h $REDIS_IP -p $REDIS_PORT cluster nodes \
| awk -F[\ \:\@] '!/ERR/{ printf("%s:%s\n",$2,$3); }'`
else
    redis_nodes=`redis-cli --no-auth-warning -a "$redis_password" -h $REDIS_IP -p $REDIS_PORT cluster nodes \
| awk -F[\ \:\@] '!/ERR/{ printf("%s:%s\n",$2,$3); }'`
fi
if test -z "$redis_nodes"; then
    # standlone
    #$REDIS_CLI -h $REDIS_IP -p $REDIS_PORT FLUSHALL
    $REDIS_CLI -h $REDIS_IP -p $REDIS_PORT INFO
else
    # cluster
    for redis_node in $redis_nodes;
    do
        if test ! -z "$redis_node"; then
            eval $(echo "$redis_node" | awk -F[\:] '{ printf("redis_node_ip=%s\nredis_node_port=%s\n",$1,$2) }')

            if test ! -z "$redis_node_ip" -a ! -z "$redis_node_port"; then
                if test -z "$redis_password"; then
                    items=(`$REDIS_CLI -h $redis_node_ip -p $redis_node_port INFO MEMORY 2>&1 | tr '\r' ' '`)
                else
                    items=(`$REDIS_CLI --no-auth-warning -a "$redis_password" -h $redis_node_ip -p $redis_node_port INFO MEMORY 2>&1 | tr '\r' ' '`)
                fi

                used_memory_human=0
                used_memory_rss_human=0
                used_memory_peak_human=0
                maxmemory_human=0
                total_system_memory_human=0
                for item in "${items[@]}"
                do
                    eval $(echo "$item" | awk -F[\:] '{ printf("name=%s\nvalue=%s\n",$1,$2) }')

                    if test "$name" = "used_memory_human"; then
                        used_memory_human=$value
                    elif test "$name" = "used_memory_rss_human"; then
                        used_memory_rss_human=$value
                    elif test "$name" = "used_memory_peak_human"; then
                        used_memory_peak_human=$value
                    elif test "$name" = "maxmemory_human"; then
                        maxmemory_human=$value
                    elif test "$name" = "total_system_memory_human"; then
                        total_system_memory_human=$value
                    fi
                done

                echo -e "[\033[1;33m${redis_node_ip}:${redis_node_port}\033[m]\tVIRT: \033[0;32;32m$used_memory_human\033[m\tRSS: \033[0;32;32m$used_memory_rss_human\033[m\tPeak: \033[0;32;32m$used_memory_peak_human\033[m\tMax: \033[0;32;32m$maxmemory_human\033[m\tSystem: \033[0;32;32m$total_system_memory_human\033[m"
            fi
        fi
    done
fi

echo "
used_memory_human=显示返回使用的内存量
used_memory_rss_human=显示该进程所占物理内存的大小
used_memory_peak_human=显示返回redis的内存消耗峰值
maxmemory_human=显示Redis实例的最大内存配置
total_system_memory_human=显示整个系统内存"
