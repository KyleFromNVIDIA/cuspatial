/*
 * Copyright (c) 2023, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <cuspatial_test/base_fixture.hpp>
#include <cuspatial_test/vector_equality.hpp>
#include <cuspatial_test/vector_factories.cuh>

#include <cuspatial/constants.hpp>
#include <cuspatial/error.hpp>
#include <cuspatial/experimental/allpairs_multipoint_equals_count.cuh>
#include <cuspatial/experimental/sinusoidal_projection.cuh>
#include <cuspatial/vec_2d.hpp>

#include <rmm/device_vector.hpp>

#include <thrust/iterator/transform_iterator.h>

using namespace cuspatial;
using namespace cuspatial::test;

template <typename T>
struct AllpairsMultipointEqualsCountTest : public BaseFixture {
  void run_single(std::initializer_list<std::initializer_list<vec_2d<T>>> lhs_coordinates,
                  std::initializer_list<std::initializer_list<vec_2d<T>>> rhs_coordinates,
                  std::initializer_list<uint32_t> expected)
  {
    auto larray = make_multipoints_array(lhs_coordinates);
    auto rarray = make_multipoints_array(rhs_coordinates);

    auto lrange = larray.range();
    auto rrange = rarray.range();

    auto lhs = lrange[0];
    auto rhs = rrange[0];

    auto got = rmm::device_uvector<uint32_t>(lhs.size(), stream());

    auto ret = allpairs_multipoint_equals_count(lhs, rhs, got.begin(), stream());

    auto d_expected = cuspatial::test::make_device_vector(expected);
    CUSPATIAL_EXPECT_VECTORS_EQUIVALENT(got, d_expected);
    EXPECT_EQ(ret, got.end());
  }
};

using TestTypes = ::testing::Types<float, double>;

TYPED_TEST_CASE(AllpairsMultipointEqualsCountTest, TestTypes);

TYPED_TEST(AllpairsMultipointEqualsCountTest, EmptyInput)
{
  using T = TypeParam;
  using P = vec_2d<T>;
  CUSPATIAL_RUN_TEST(this->run_single,
                     std::initializer_list<std::initializer_list<P>>{{}},
                     std::initializer_list<std::initializer_list<P>>{{}},
                     {});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, OneOneEqual)
{
  CUSPATIAL_RUN_TEST(this->run_single, {{{0, 0}}}, {{{0, 0}}}, {1});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, OneOneNotEqual)
{
  CUSPATIAL_RUN_TEST(this->run_single, {{{0, 0}}}, {{{1, 0}}}, {0});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, OneTwoEqual)
{
  CUSPATIAL_RUN_TEST(this->run_single, {{{0, 0}}}, {{{1, 1}, {0, 0}}}, {1});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, ThreeOneEqual)
{
  CUSPATIAL_RUN_TEST(this->run_single, {{{0, 0}, {1, 1}, {2, 2}}}, {{{1, 1}}}, {0, 1, 0});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, ThreeOneNotEqual)
{
  CUSPATIAL_RUN_TEST(this->run_single, {{{0, 0}, {1, 1}, {2, 2}}}, {{{-1, -1}}}, {0, 0, 0});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, OneThreeEqual)
{
  CUSPATIAL_RUN_TEST(this->run_single, {{{1, 1}}}, {{{0, 0}, {1, 1}, {0, 0}}}, {1});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, OneThreeNotEqual)
{
  CUSPATIAL_RUN_TEST(this->run_single, {{{1, 1}}}, {{{0, 0}, {0, 0}, {1, 1}}}, {1});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, ThreeThreeEqualMiddle)
{
  CUSPATIAL_RUN_TEST(
    this->run_single, {{{0, 0}, {1, 1}, {2, 2}}}, {{{-1, -1}, {1, 1}, {-1, -1}}}, {0, 1, 0});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, ThreeThreeNotEqualMiddle)
{
  CUSPATIAL_RUN_TEST(
    this->run_single, {{{0, 0}, {1, 1}, {2, 2}}}, {{{0, 0}, {-1, -1}, {2, 2}}}, {1, 0, 1});
}

TYPED_TEST(AllpairsMultipointEqualsCountTest, ThreeThreeNeedRhsMultipoints)
{
  CUSPATIAL_RUN_TEST(this->run_single,
                     {{{0, 0}, {1, 1}, {2, 2}}},
                     {{{0, 0}, {1, 1}}, {{2, 2}, {3, 3}}, {{0, 0}, {1, 1}}},
                     {2, 0, 2});
}
