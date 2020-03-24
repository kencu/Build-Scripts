#include <array>
int main(int argc, char* argv[])
{
    std::array<unsigned int, 4_k> x;
    return x[0];
}
