#include <iostream>
#include <fstream>
#include <sstream>
#include <string>

void usage_exit();
void process_stream(std::istream&);
std::string fix_options(const std::string&);

int main(int argc, char* argv[])
{
    if (argc > 2)
        usage_exit();

    if (argc == 1)
    {
        process_stream(std::cin);
    }
    else
    {
        std::ifstream infile (argv[1]);
        process_stream(infile);
    }

    return 0;
}

void process_stream(std::istream& stream)
{
    std::string line;
    while (std::getline(stream, line))
    {
        std::cout << fix_options(line) << std::endl;
    }
}

std::string fix_options(const std::string& line)
{
    std::string new_line;

    if (line.substr(0, 5) == "Libs:")
        new_line = "Libs:";
    else if (line.substr(0, 13) == "Libs.private:")
        new_line = "Libs.private:";
    else
        return line;

    std::string t;
    std::istringstream stream(line);

    while (getline(stream, t, ' '))
    {
        if (t.empty())
            continue;

        if (t.substr(0,2) == "-l")
            new_line += std::string(" ") + t;
        else if (t.substr(0,2) == "-L")
            new_line += std::string(" ") + t;
    }

    return new_line;
}

void usage_exit()
{
    std::cerr << "Usage: fix-pkgconfig <pc_file>" << std::endl;
    std::cerr << "   or: cat <pc_file> | fix-pkgconfig" << std::endl;
    exit(1);
}
