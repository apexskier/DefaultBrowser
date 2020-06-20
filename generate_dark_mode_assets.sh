#!/usr/bin/env bash

imagesets=$( \
    ls DefaultBrowser/Assets.xcassets/ | \
    grep '^StatusBarButtonImage' | \
    grep -v 'Error\.' | \
    grep -v 'StatusBarButtonImage.imageset' \
)

for imageset in $imagesets
do
    browser=${imageset%.*}
    browser=${browser#StatusBarButtonImage}
    name="DefaultBrowser${browser}"
    light_1x_name="${name}@1x.png"
    light_2x_name="${name}@2x.png"
    dark_1x_name="${name}_Dark@1x.png"
    dark_2x_name="${name}_Dark@2x.png"
    # invert the browser icon part of the default browser icon
    convert "DefaultBrowser/Assets.xcassets/$imageset/$light_1x_name" -region 14x8+1+7 -channel A -negate -transparent black "DefaultBrowser/Assets.xcassets/$imageset/$dark_1x_name"
    # # invert the browser icon part of the default browser icon
    convert "DefaultBrowser/Assets.xcassets/$imageset/$light_2x_name" -region 28x21+2+9 -channel A -negate -transparent black "DefaultBrowser/Assets.xcassets/$imageset/$dark_2x_name"
    cp "DefaultBrowser/Assets.xcassets/$imageset/Contents.json" "DefaultBrowser/Assets.xcassets/$imageset/Contents.json.bak"
    cat "DefaultBrowser/Assets.xcassets/$imageset/Contents.json.bak" | jq -r '.images += [{"idiom": "mac", "filename": "'$dark_1x_name'", "scale": "1x", "appearances": [{"appearance": "luminosity", value: "dark"}]}, {"idiom": "mac", "filename": "'$dark_2x_name'", "scale": "2x", "appearances": [{"appearance": "luminosity", value: "dark"}]}]' > "DefaultBrowser/Assets.xcassets/$imageset/Contents.json"
done

