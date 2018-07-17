#!/bin/bash

xml_folder_path="xmlfolder"

rm -rf homeopathic
rm -rf otc
rm -rf prescription
rm -rf other
rm -rf $xml_folder_path

#dm_spl_release_homeopathic
echo "unzipping dm_spl_release_homeopathic (1/4)..."
unzip -oq dm_spl_release_homeopathic.zip

#dm_spl_release_human_otc
echo "unzipping dm_spl_release_human_otc_part1 (2/4)..."
unzip -oq dm_spl_release_human_otc_part1.zip
echo "unzipping dm_spl_release_human_otc_part2 (2/4)..."
unzip -oq dm_spl_release_human_otc_part2.zip
echo "unzipping dm_spl_release_human_otc_part3 (2/4)..."
unzip -oq dm_spl_release_human_otc_part3.zip
echo "unzipping dm_spl_release_human_otc_part4 (2/4)..."
unzip -oq dm_spl_release_human_otc_part4.zip

#dm_spl_release_human_rx
echo "unzipping dm_spl_release_human_rx_part1 (3/4)..."
unzip -oq dm_spl_release_human_rx_part1.zip
echo "unzipping dm_spl_release_human_rx_part2 (3/4)..."
unzip -oq dm_spl_release_human_rx_part2.zip
echo "unzipping dm_spl_release_human_rx_part3 (3/4)..."
unzip -oq dm_spl_release_human_rx_part3.zip

#dm_spl_release_remainder
echo "unzipping dm_spl_release_remainder (4/4)..."
unzip -oq dm_spl_release_remainder.zip

echo "unzipping xml files from dm_spl_release_homeopathic..."
for z in homeopathic/*.zip; do unzip -oq -d $xml_folder_path $z \*.xml; done

echo "unzipping xml files from dm_spl_release_human_otc..."
for z in otc/*.zip; do unzip -oq -d $xml_folder_path $z \*.xml; done

echo "unzipping xml files from dm_spl_release_human_rx..."
for z in prescription/*.zip; do unzip -oq -d $xml_folder_path $z \*.xml; done

echo "unzipping xml files from dm_spl_release_remainder..."
for z in other/*.zip; do unzip -oq -d $xml_folder_path $z \*.xml; done


#ls $xml_folder_path/*.xml > allxmlfilelist.dat #gets error "/bin/ls: Argument list too long"
find $xml_folder_path -maxdepth 1 -name "*.xml" > allxmlfilelist.dat

echo "unzipping done"
#echo "cleaning..."
#rm -rf homeopathic
#rm -rf otc
#rm -rf prescription
#rm -rf other
#rm -rf $xml_folder_path
#echo "done"