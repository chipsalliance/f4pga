#include <clocks.h>

#include <gtest/gtest.h>

TEST(ClockTest, EscapeDollarSign)
{
    // convert wire_name to wire_name, i.e. unchanged
    EXPECT_EQ(Clock::AddEscaping("wire_name"), "wire_name");
    // convert $wire_name to \$wire_name
    EXPECT_EQ(Clock::AddEscaping("$wire_name"), "\\$wire_name");
}
