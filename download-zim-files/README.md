# Run command

```bash
bash -c "$(wget -qLO - https://github.com/bigbeartechworld/big-bear-scripts/raw/master/download-zim-files/run.sh)"
```

# How to use

Run the script with the URL of the ZIM file as the first argument, like so:

```bash
bash -c "$(wget -qLO - https://github.com/bigbeartechworld/big-bear-scripts/raw/master/download-zim-files/run.sh)" -- <url> <custom_destination_directory>
```

Replace `<url>` with the URL of the ZIM file you want to download, and `<custom_destination_directory>` with the path to the directory where you want to save the ZIM file.

If `<custom_destination_directory>` is not provided, the script will use the default destination directory `/DATA/AppData/big-bear-kiwix-serve/zim`.

Example:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/bigbeartechworld/big-bear-scripts/master/download-zim-files/run.sh)" -- https://download.kiwix.org/zim/other/termux_en_all_maxi_2022-12.zim
```
