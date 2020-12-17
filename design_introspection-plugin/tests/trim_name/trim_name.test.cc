#include "../common/utils.h"

#include <gtest/gtest.h>

TEST(UtilitiesTest, TrimName)
{
    std::string original("  wire_name  ");
    // trim wire_name from both sides
    std::string name(original);
    trim(name);
    EXPECT_EQ(name, "wire_name");

    // trim wire_name from left-hand side
    name = original;
    trim_left(name);
    EXPECT_EQ(name, "wire_name  ");

    // trim wire_name from right-hand side
    name = original;
    trim_right(name);
    EXPECT_EQ(name, "  wire_name");
}
