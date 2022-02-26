#!/bin/sh -e

GFWURL="https://pagure.io/gfwlist/raw/master/f/gfwlist.txt"
APNIC="http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest"
IPSETNAME="pubvpn"
PUBDNS='127.0.0.1#5353'
WORKDIR=$(mktemp -d)
CONFDIR="/tmp/dnsmasq.d/"
CONFILE="gfwlist.conf"

generate_china_banned()
{

	wget -qO- --no-check-certificate $GFWURL |base64 -d | sed -e '/^@@|/d'| sort -u |
		sed 's#!.\+##; s#|##g; s#@##g; s#http:\/\/##; s#https:\/\/##;' |
		sed '/\*/d; /apple\.com/d; /sina\.cn/d; /sina\.com\.cn/d; /baidu\.com/d; /byr\.cn/d; /jlike\.com/d; /weibo\.com/d; /zhongsou\.com/d; /youdao\.com/d; /sogou\.com/d; /so\.com/d; /soso\.com/d; /aliyun\.com/d; /taobao\.com/d; /jd\.com/d; /qq\.com/d' |
		sed '/^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$/d' |
		grep '^[0-9a-zA-Z\.-]\+$' | grep '\.' | sed 's#^\.\+##' | sort -u
#		awk '
#			BEGIN
#			{
#				prev = "________";
#			}
#
#			{
#				cur = $0;
#				if (index(cur, prev) == 1 && substr(cur, 1 + length(prev) ,1) == ".")
#				{}
#				else {
#					print cur;
#					prev = cur;
#				}
#			}' | sort -u

}

generate_china_ips()
{
	wget -qO- -t 3 -T 3 $APNIC |
		grep ipv4 | grep CN |
		awk -F\| '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }'
}

reload_gfwlist(){
######################### reload the gfwlist ###################
        generate_china_banned  |grep -vi github|sed '/.*/s/.*/server=\/\.&\/'$PUBDNS'\nipset=\/\.&\/'$IPSETNAME'/' | tee $WORKDIR/$CONFILE

        if [ -s $WORKDIR/$CONFILE ];then

        	GFWMD5=$(md5sum $WORKDIR/$CONFILE |awk '{print $1}')
        	GFWMD5OLD=$(md5sum $CONFDIR/$CONFILE |awk '{print $1}')

        	if [ $GFWMD5 == $GFWMD5OLD ];then
        		rm -rf $WORKDIR
        	else
        		mv $WORKDIR/$CONFILE $CONFDIR/$CONFILE
        	fi

        else

        	echo 连接gfw地址失败，请重试
        	rm -rf $WORKDIR
        	exit 2

        fi
        rm -rf $WORKDIR
        /etc/init.d/dnsmasq restart
}

reload_chnips(){
##################### reload the cn list ########################
        generate_china_ips >/tmp/cn.txt

        CNMD5=$(md5sum /tmp/cn.txt |awk '{print $1}')
        CNMD5OLD=$(md5sum /etc/mwan3helper/all_cn.txt |awk '{print $1}')

        if [ $CNMD5 == $CNMD5OLD ];then
        	rm -f /tmp/cn.txt
        else
        	mv /tmp/cn.txt /etc/mwan3helper/all_cn.txt
        fi

        /etc/mwan3helper/genipset.sh cn '/etc/mwan3helper/all_cn.txt'
}
reload_gfwlist
#reload_chnips
