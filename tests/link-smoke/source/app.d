module app;

import fastjsond;

void main()
{
    auto parser = Parser.create();
    assert(parser.valid);

    auto document = parser.parse(`{"name":"Aurora","count":3}`);
    assert(document.valid);
    assert(document.root["name"].getString == "Aurora");
    assert(document.root["count"].getInt == 3);
}
