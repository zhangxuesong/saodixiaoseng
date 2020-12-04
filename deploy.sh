#!/bin/sh

hugo

cp -rf public/* ../zhangxuesong.github.io/docs/

cd ../zhangxuesong.github.io/

git add * && git commit -m 'new article' && git push

cd ../saodixiaoseng/
